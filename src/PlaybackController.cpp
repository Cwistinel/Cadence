#include "PlaybackController.h"
#include "Database.h"
#include "TrackDb.h"
#include <QDateTime>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSet>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <numeric>

namespace {
// Runtime state lives in the DB `settings` table (prefix "state/") so backups carry it along with the queue.
void put(const QString &k, const QVariant &v) { Database::run("INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)", {QString("state/") + k, v.toString()}); }
QString get(const QString &k, const QString &d = {}) { QSqlQuery q = Database::run("SELECT value FROM settings WHERE key=?", {QString("state/") + k}); return q.next() ? q.value(0).toString() : d; }
QList<qint64> toIds(const QVariantList &l) { QList<qint64> o; o.reserve(l.size()); for (const QVariant &v : l) o << v.toLongLong(); return o; }
bool sameItem(const Track &t, const PlayItem &p) { return t.path == p.path && t.startMs == p.startMs; }
}  // namespace

PlaybackController::PlaybackController(AudioEngine *e, Settings *s, UndoStack *u, QObject *p)
    : QObject(p), m_engine(e), m_set(s), m_undo(u), m_q(this) {
    m_saveTimer.setSingleShot(true); m_saveTimer.setInterval(800);
    m_posTimer.setInterval(5000);
    connect(&m_saveTimer, &QTimer::timeout, this, &PlaybackController::flush);
    connect(&m_posTimer, &QTimer::timeout, this, &PlaybackController::savePosition);
    connect(e, &AudioEngine::stateChanged, this, &PlaybackController::onState);
    connect(e, &AudioEngine::positionChanged, this, &PlaybackController::onPosition);
    connect(e, &AudioEngine::durationChanged, this, &PlaybackController::durationChanged);
    connect(e, &AudioEngine::advanced, this, &PlaybackController::onAdvanced);
    connect(e, &AudioEngine::finished, this, &PlaybackController::onFinished);
    connect(e, &AudioEngine::error, this, &PlaybackController::onError);
    connect(e, &AudioEngine::devicesChanged, this, &PlaybackController::devicesChanged);
    connect(e, &AudioEngine::deviceChanged, this, &PlaybackController::onDevice);
    connect(s, &Settings::changed, this, &PlaybackController::onSetting);
    applyAll();
    restore();
}

// ---------- read-only state ----------

qint64 PlaybackController::duration() const {
    const qint64 d = m_engine->state() != AudioEngine::Stopped ? m_engine->duration() : 0;
    return d > 0 ? d : (m_cur >= 0 ? m_q.at(m_cur).durationMs : 0);
}

bool PlaybackController::canNext() const { return m_q.count() > 0 && (m_op < 0 || m_op + 1 < m_q.count() || m_repeat != Off); }

const Track &PlaybackController::currentTrack() const { static const Track none; return m_cur >= 0 ? m_q.at(m_cur) : none; }

QVariantMap PlaybackController::trackMap() const {
    if (m_cur < 0) return {};
    const Track &t = m_q.at(m_cur);
    return {{"id", t.id}, {"title", t.title.isEmpty() ? QFileInfo(t.path).completeBaseName() : t.title}, {"artist", t.artist},
            {"album", t.album}, {"albumArtist", t.albumArtist}, {"genre", t.genre}, {"trackNo", t.trackNo}, {"year", t.year},
            {"durationMs", t.durationMs}, {"path", t.path}, {"favorite", t.favorite}, {"virtual", t.isVirtual()}};
}

// ---------- setters ----------

void PlaybackController::setVolume(double v) { m_engine->setVolume(v); emit volumeChanged(); scheduleSave(); }
void PlaybackController::setMuted(bool m) { m_engine->setMuted(m); emit volumeChanged(); }
void PlaybackController::volumeBy(double d) { setVolume(volume() + d); }
void PlaybackController::setSpeed(double s) { m_set->setValue("audio/speed", qBound(0.5, s, 2.0)); }   // applied by onSetting()

void PlaybackController::setShuffle(bool on) {
    if (on == m_shuffle) return;
    m_shuffle = on; resetOrder(); armNext();
    emit modeChanged(); emit navChanged(); scheduleSave();
}

void PlaybackController::setRepeat(int r) {
    r = qBound(0, r, 2);
    if (r == m_repeat) return;
    m_repeat = r; armNext();
    emit modeChanged(); emit navChanged(); scheduleSave();
}

void PlaybackController::setDevice(const QString &name) {
    m_set->setValue("audio/device", name);
    if (m_engine->device() != name) m_engine->setDevice(name);   // also covers re-selecting a device that vanished and came back
}

// ---------- settings -> engine ----------

void PlaybackController::applyAll() {
    for (const char *k : {"audio/gapless", "audio/crossfadeMs", "audio/speed", "audio/eqEnabled", "audio/device"}) onSetting(QString::fromLatin1(k));
}

void PlaybackController::onSetting(const QString &k) {
    if (k == "audio/gapless") m_engine->setGapless(m_set->value(k, true).toBool());
    else if (k == "audio/crossfadeMs") m_engine->setCrossfade(m_set->value(k, 0).toInt());
    else if (k == "audio/speed") { m_engine->setSpeed(m_set->value(k, 1.0).toDouble()); emit speedChanged(); }
    else if (k == "audio/eqEnabled" || k == "audio/eqGains") applyEq();
    else if (k == "audio/device") m_engine->setDevice(m_set->value(k, QString()).toString());
    else if (k == "audio/replayGain") restartCurrent();
}

void PlaybackController::applyEq() {
    QList<double> g;
    for (const QString &s : m_set->value("audio/eqGains", QString("0,0,0,0,0,0,0,0,0,0")).toString().split(QLatin1Char(','))) g << s.toDouble();
    while (g.size() < 10) g << 0.0;
    m_engine->setEqualizer(m_set->value("audio/eqEnabled", false).toBool(), g);
}

// The engine has no live gain setter, so a ReplayGain change re-opens the current track at the same position (brief blip).
void PlaybackController::restartCurrent() {
    if (m_cur >= 0 && m_engine->state() != AudioEngine::Stopped)
        m_engine->play(toItem(m_q.at(m_cur)), m_engine->state() == AudioEngine::Playing, m_pos);
    armNext();
}

double PlaybackController::gain(const Track &t) const {
    const QString m = m_set->value("audio/replayGain", QString("off")).toString();
    if (m != "track" && m != "album") return 0;
    const bool album = t.hasRgAlbum && (m == "album" || !t.hasRgTrack);
    if (!album && !t.hasRgTrack) return 0;
    const double g = album ? t.rgAlbum : t.rgTrack, pk = album ? t.peakAlbum : t.peakTrack;
    return qBound(-30.0, pk > 0 ? qMin(g, -20.0 * std::log10(pk)) : g, 12.0);   // peak-limited: never clips
}

PlayItem PlaybackController::toItem(const Track &t) const { return PlayItem{t.path, t.startMs, t.endMs, t.durationMs, gain(t)}; }

// ---------- transport ----------

void PlaybackController::play() {
    if (m_cur < 0) { if (m_q.count()) startIndex(m_order.value(0, 0)); return; }
    if (m_engine->state() == AudioEngine::Paused) m_engine->resume();
    else if (m_engine->state() == AudioEngine::Stopped) startIndex(m_cur, true, m_pos);
}

void PlaybackController::pause() { m_engine->pause(); }
void PlaybackController::togglePlayPause() { if (playing()) pause(); else play(); }
void PlaybackController::stop() { m_engine->stop(); }

void PlaybackController::next() { const int n = peekNext(true); if (n >= 0) startIndex(n); }

void PlaybackController::previous() {
    if (m_cur < 0) return;
    int p = -1;
    if (m_pos <= 3000) p = m_op > 0 ? m_order[m_op - 1] : (m_repeat == All && m_order.size() > 1 ? m_order.last() : -1);
    if (p < 0) seek(0); else startIndex(p);
}

void PlaybackController::seek(qint64 ms) {
    ms = qMax<qint64>(0, ms);
    if (m_engine->state() == AudioEngine::Stopped) { m_pos = ms; emit positionChanged(ms); }   // applied when playback starts
    else m_engine->seek(ms);
    emit seeked(ms);
}

void PlaybackController::seekBy(qint64 d) { seek(m_pos + d); }
void PlaybackController::playIndex(int i) { startIndex(i); }

void PlaybackController::startIndex(int i, bool autoplay, qint64 resume) {
    if (i < 0 || i >= m_q.count()) return;
    setCurrent(i);
    m_failures = 0; m_badNext = -1; m_counted = resume > 0;   // resumed tracks were already counted
    m_pos = resume;
    m_engine->play(toItem(m_q.at(i)), autoplay, resume);
    armNext();
}

void PlaybackController::setCurrent(int i) {
    m_cur = i; m_op = m_order.indexOf(i); m_counted = false;
    m_q.setCurrent(i);
    emit trackChanged(); emit navChanged(); emit durationChanged();
    scheduleSave();
}

// ---------- next-track selection ----------

int PlaybackController::peekNext(bool manual) {
    const int n = m_q.count();
    if (n == 0) return -1;
    if (m_op < 0) return m_order.value(0, -1);
    if (m_op + 1 < n) return m_order[m_op + 1];
    if (m_repeat == Off || (m_repeat == One && !manual)) return -1;
    if (m_shuffle && n > 1) { resetOrder(); return m_order[1]; }   // repeat-all + shuffle: new random pass starting with the current track
    return m_order[0];
}

void PlaybackController::armNext() {
    int n = -1;
    if (m_cur >= 0) n = m_repeat == One ? m_cur : peekNext(false);
    if (n >= 0 && n == m_badNext) n = -1;
    m_pending = n;
    m_engine->setNext(n >= 0 ? toItem(m_q.at(n)) : PlayItem());
}

void PlaybackController::resetOrder() {   // identity, or a fresh shuffle with the current track first
    m_order.resize(m_q.count());
    std::iota(m_order.begin(), m_order.end(), 0);
    if (m_shuffle) {
        if (m_cur >= 0) m_order.move(m_cur, 0);
        std::shuffle(m_order.begin() + (m_cur >= 0), m_order.end(), *QRandomGenerator::global());
    }
    m_op = m_cur >= 0 ? int(m_order.indexOf(m_cur)) : -1;
}

// After a queue edit: f maps old indices to new ones (-1 = removed). History and the current track keep their place;
// new indices are shuffled into the upcoming part only when something was added.
void PlaybackController::applyMap(const std::function<int(int)> &f) {
    if (m_cur >= 0) m_cur = f(m_cur);
    m_badNext = -1;
    if (!m_shuffle) { resetOrder(); return; }
    QList<int> o;
    for (int v : m_order) if (const int r = f(v); r >= 0) o << r;
    m_op = int(o.indexOf(m_cur));
    QList<bool> seen(m_q.count(), false);
    for (int v : o) seen[v] = true;
    QList<int> rest = o.mid(m_op + 1);
    const qsizetype before = rest.size();
    for (int i = 0; i < m_q.count(); ++i) if (!seen[i]) rest << i;
    if (rest.size() != before) std::shuffle(rest.begin(), rest.end(), *QRandomGenerator::global());
    m_order = o.mid(0, m_op + 1) + rest;
}

// ---------- engine events ----------

void PlaybackController::onState() {
    const bool pl = playing();
    if (pl) m_posTimer.start(); else { m_posTimer.stop(); savePosition(); }   // no timers or writes while idle
    emit stateChanged();
}

void PlaybackController::onPosition(qint64 ms) {
    m_pos = ms;
    emit positionChanged(ms);
    if (m_counted || m_cur < 0 || !playing()) return;
    const qint64 d = duration(), need = d > 0 ? qMin<qint64>(30000, d / 2) : 30000;   // a play counts after 30 s or half the track
    if (ms >= need) { m_counted = true; recordPlay(m_q.at(m_cur).id); }
}

void PlaybackController::onAdvanced() {
    const PlayItem &c = m_engine->current();
    int i = m_pending >= 0 && m_pending < m_q.count() && sameItem(m_q.at(m_pending), c) ? m_pending : -1;
    for (int k = 0; i < 0 && k < m_q.count(); ++k) if (sameItem(m_q.at(k), c)) i = k;   // queue was edited at the last moment
    if (i < 0) { m_engine->stop(); return; }
    setCurrent(i);
    m_failures = 0; m_pos = 0;
    emit positionChanged(0);
    armNext();
}

void PlaybackController::onFinished() {
    if (m_badNext >= 0) {                      // the armed next track failed to open: skip over it
        setCurrent(m_badNext); m_badNext = -1;
        if (const int n = peekNext(false); n >= 0) { startIndex(n); return; }
    }
    if (m_q.count()) { setCurrent(m_order.value(0, 0)); m_pos = 0; emit positionChanged(0); armNext(); }   // queue done: ready from the top
}

void PlaybackController::onError(const QString &path, const QString &msg, bool wasCurrent) {
    emit message(tr("Can't play %1: %2").arg(QFileInfo(path).fileName(), msg));
    if (!wasCurrent) { m_badNext = m_pending; armNext(); return; }   // crossfade target failed: current track keeps playing
    const int failures = m_failures + 1, n = peekNext(false);
    if (n >= 0 && failures < qMax(1, m_q.count())) { startIndex(n); m_failures = failures; }   // skip unplayable files, but not forever
}

void PlaybackController::onDevice() {
    emit deviceChanged();
    if (m_engine->device().isEmpty() && !m_set->value("audio/device", QString()).toString().isEmpty())
        emit message(tr("Output device unavailable. Using the system default."));
}

// ---------- queue editing ----------

void PlaybackController::insertRaw(int at, const QList<Track> &ts) {
    at = qBound(0, at, m_q.count());
    const int n = int(ts.size());
    m_q.insert(at, ts);
    applyMap([at, n](int v) { return v >= at ? v + n : v; });
    armNext(); scheduleSave(); emit navChanged();
}

void PlaybackController::removeRaw(int i) {
    const bool wasCur = i == m_cur, wasPlaying = playing();
    const int nx = wasCur ? peekNext(false) : -1;
    const qint64 nid = nx >= 0 && nx != i ? m_q.at(nx).id : 0;
    m_q.take(i);
    applyMap([i](int v) { return v == i ? -1 : v > i ? v - 1 : v; });
    if (wasCur) {
        const int ni = m_q.indexOfId(nid);
        if (ni >= 0 && wasPlaying) startIndex(ni);
        else { m_engine->stop(); setCurrent(ni); m_pos = 0; armNext(); }
    } else armNext();
    scheduleSave(); emit navChanged();
}

void PlaybackController::moveRaw(int from, int to) {
    m_q.move(from, to);
    applyMap([from, to](int v) { if (v == from) return to; if (from < to && v > from && v <= to) return v - 1; if (from > to && v >= to && v < from) return v + 1; return v; });
    armNext(); scheduleSave();
}

void PlaybackController::removeAt(int i) {
    if (i < 0 || i >= m_q.count()) return;
    const Track t = m_q.at(i);
    removeRaw(i);
    m_undo->push(tr("Removed from queue"), [this, t, i] { insertRaw(i, {t}); });
}

void PlaybackController::moveTrack(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= m_q.count() || to >= m_q.count()) return;
    moveRaw(from, to);
    m_undo->push(tr("Queue reordered"), [this, from, to] { moveRaw(to, from); });
}

void PlaybackController::clearQueue() {
    m_engine->stop(); m_q.clear(); m_order.clear(); m_op = -1;
    setCurrent(-1); armNext();
}

void PlaybackController::add(const QList<Track> &ts, bool afterCurrent) {
    QSet<qint64> have;
    for (const Track &t : m_q.tracks()) have.insert(t.id);
    QList<Track> fresh;
    for (const Track &t : ts) if (!have.contains(t.id)) { have.insert(t.id); fresh << t; }
    if (const qsizetype dup = ts.size() - fresh.size(); dup > 0) emit message(tr("%1 already in the queue").arg(dup));
    if (fresh.isEmpty()) return;
    const int at = afterCurrent && m_cur >= 0 ? m_cur + 1 : m_q.count(), n = int(fresh.size());
    insertRaw(at, fresh);
    if (afterCurrent && m_shuffle && m_cur >= 0) {   // "play next" must also be next in the shuffled order
        for (int k = 0; k < n; ++k) m_order.removeOne(at + k);
        for (int k = 0; k < n; ++k) m_order.insert(m_op + 1 + k, at + k);
        armNext();
    }
    if (m_cur < 0) { setCurrent(m_order.value(0, -1)); m_pos = 0; emit positionChanged(0); armNext(); }
}

void PlaybackController::replaceQueue(const QList<Track> &in, qint64 startId) {
    QSet<qint64> seen;
    QList<Track> ts;
    for (const Track &t : in) if (!seen.contains(t.id)) { seen.insert(t.id); ts << t; }
    if (ts.isEmpty()) { emit message(tr("Nothing playable found")); return; }
    int s = 0;
    for (int i = 0; i < ts.size(); ++i) if (ts[i].id == startId) { s = i; break; }
    m_q.clear(); m_q.insert(0, ts);
    m_cur = s; resetOrder();
    startIndex(s);
}

void PlaybackController::playTracks(const QVariantList &ids, int start) {
    replaceQueue(TrackDb::loadMany(toIds(ids)), start >= 0 && start < ids.size() ? ids[start].toLongLong() : 0);
}

void PlaybackController::enqueue(const QVariantList &ids, bool after) { add(TrackDb::loadMany(toIds(ids)), after); }

QList<qint64> PlaybackController::idsInFolder(const QString &path) const {
    QString p = path.startsWith("file:") ? QUrl(path).toLocalFile() : path;
    while (p.size() > 1 && p.endsWith('/')) p.chop(1);
    QSqlQuery q = Database::run("SELECT id FROM v_tracks WHERE dir=? OR substr(dir,1,length(?)+1)=?||'/' ORDER BY dir, album, track_no, title, start_ms", {p, p, p});
    QList<qint64> ids;
    while (q.next()) ids << q.value(0).toLongLong();
    return ids;
}

void PlaybackController::playFolder(const QString &path) { replaceQueue(TrackDb::loadMany(idsInFolder(path)), 0); }
void PlaybackController::enqueueFolder(const QString &path, bool after) { add(TrackDb::loadMany(idsInFolder(path)), after); }

// ---------- favorites, history, row refresh ----------

void PlaybackController::toggleFavorite() { if (m_cur >= 0) setFavorite(m_q.at(m_cur).id, !m_q.at(m_cur).favorite); }

void PlaybackController::setFavorite(qint64 id, bool on) {
    QSqlQuery q = Database::run("SELECT favorite FROM tracks WHERE id=?", {id});
    if (!q.next() || q.value(0).toBool() == on) return;
    writeFavorite(id, on);
    m_undo->push(on ? tr("Favorite added") : tr("Favorite removed"), [this, id, on] { writeFavorite(id, !on); });
}

void PlaybackController::writeFavorite(qint64 id, bool on) {
    Database::run("UPDATE tracks SET favorite=? WHERE id=?", {on ? 1 : 0, id});
    refreshTrack(id);
}

void PlaybackController::refreshTrack(qint64 id) {
    if (const Track t = TrackDb::load(id); t.id)
        for (int i = 0; i < m_q.count(); ++i) if (m_q.at(i).id == id) { m_q.replace(i, t); if (i == m_cur) emit trackChanged(); }
    emit trackUpdated(id);
}

void PlaybackController::recordPlay(qint64 id) {
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    QSqlDatabase db = Database::get();
    db.transaction();
    Database::run("UPDATE tracks SET play_count=play_count+1, last_played=? WHERE id=?", {now, id});
    Database::run("INSERT INTO history(track_id,played_at) VALUES(?,?)", {id, now});
    db.commit();
    emit trackUpdated(id);
}

// ---------- persistence ----------

void PlaybackController::restore() {
    QList<qint64> ids;
    QSqlQuery q = Database::run("SELECT track_id FROM queue ORDER BY pos");
    while (q.next()) ids << q.value(0).toLongLong();
    m_q.insert(0, TrackDb::loadMany(ids));
    m_shuffle = get("shuffle") == "true";
    m_repeat = qBound(0, get("repeat", "0").toInt(), 2);
    m_engine->setVolume(get("volume", "0.8").toDouble());
    const int saved = m_q.indexOfId(get("trackId").toLongLong());
    m_cur = saved >= 0 ? saved : (m_q.count() ? 0 : -1);
    resetOrder();
    if (m_cur < 0) return;
    m_q.setCurrent(m_cur);
    const qint64 pos = saved >= 0 ? get("position").toLongLong() : 0, dur = m_q.at(m_cur).durationMs;
    m_pos = dur > 0 && pos >= dur - 1000 ? 0 : pos;   // no engine is opened here: playback starts lazily on the first play()
    armNext();
}

void PlaybackController::flush() {
    QSqlDatabase db = Database::get();
    db.transaction();
    Database::run("DELETE FROM queue");
    QSqlQuery q(db);
    q.prepare("INSERT INTO queue(pos,track_id) VALUES(?,?)");
    for (int i = 0; i < m_q.count(); ++i) { q.bindValue(0, i); q.bindValue(1, m_q.at(i).id); q.exec(); }
    put("trackId", m_cur >= 0 ? m_q.at(m_cur).id : 0);
    put("position", m_pos); put("shuffle", m_shuffle); put("repeat", m_repeat); put("volume", volume());
    db.commit();
}

void PlaybackController::savePosition() { put("position", m_pos); }

void PlaybackController::shutdown() { m_saveTimer.stop(); m_posTimer.stop(); flush(); }
void PlaybackController::saveNow() { flush(); }

void PlaybackController::reloadFromDatabase() {
    m_saveTimer.stop();
    if (m_engine->state() != AudioEngine::Stopped) m_engine->stop();
    m_engine->setNext(PlayItem());
    m_q.clear(); m_order.clear(); m_cur = m_op = m_pending = m_badNext = -1; m_pos = 0;
    restore(); applyAll();
    emit trackChanged(); emit navChanged(); emit modeChanged(); emit volumeChanged(); emit speedChanged();
    emit positionChanged(m_pos); emit durationChanged(); emit stateChanged();
}