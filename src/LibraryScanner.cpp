#include <QLocale>
#include "LibraryScanner.h"
#include "CueParser.h"
#include "Database.h"
#include "Metadata.h"
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QMap>
#include <QSet>
#include <QUrl>
#include <QDesktopServices>

namespace {
const QSet<QString> kExt{"mp3", "aac", "m4a", "flac", "ogg", "oga", "opus", "wav", "amr", "awb"};

QString localPath(const QString &s) { return QDir::cleanPath(QFileInfo(s.startsWith("file:") ? QUrl(s).toLocalFile() : s).absoluteFilePath()); }
bool inside(const QString &p, const QString &root) { return p == root || p.startsWith(root + '/'); }

// FILE entries are resolved next to the sheet, with a case-insensitive fallback (sheets often come from Windows).
QString resolveFile(const QString &cueDir, QString name) {
    name.replace('\\', '/');
    const QString p = QDir::cleanPath(cueDir + '/' + name);
    if (QFileInfo::exists(p)) return p;
    const QFileInfo fi(p);
    for (const QString &e : QDir(fi.absolutePath()).entryList(QDir::Files))
        if (e.compare(fi.fileName(), Qt::CaseInsensitive) == 0) return fi.absolutePath() + '/' + e;
    return {};
}

CueSheet readCue(const QString &p) {
    QFile f(p);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 2 * 1024 * 1024) { CueSheet s; s.error = QStringLiteral("unreadable"); return s; }
    return CueParser::parse(f.readAll());
}

struct Row { qint64 id = 0, mtime = 0, size = 0; bool missing = false; QString cue; };
struct CueUse { QString cuePath; qint64 cueMtime = 0; CueSheet sheet; QList<CueTrack> tracks; };

const char *kUpsert = R"(INSERT INTO tracks(path,start_ms,end_ms,folder_id,dir,title,artist,album,album_artist,genre,track_no,year,
  duration_ms,mtime,size,hash,rg_track,rg_album,peak_track,peak_album,cue_path,added_at,missing)
  VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,0)
  ON CONFLICT(path,start_ms) DO UPDATE SET end_ms=excluded.end_ms, folder_id=COALESCE(excluded.folder_id,folder_id), dir=excluded.dir,
  title=excluded.title, artist=excluded.artist, album=excluded.album, album_artist=excluded.album_artist, genre=excluded.genre,
  track_no=excluded.track_no, year=excluded.year, duration_ms=excluded.duration_ms, mtime=excluded.mtime, size=excluded.size,
  hash=excluded.hash, rg_track=excluded.rg_track, rg_album=excluded.rg_album, peak_track=excluded.peak_track,
  peak_album=excluded.peak_album, cue_path=excluded.cue_path, missing=0)";
}  // namespace

LibraryScanner::LibraryScanner(QObject *p) : QObject(p) { m_pool.setMaxThreadCount(1); loadFolders(); }

LibraryScanner::~LibraryScanner() { m_cancel = true; m_jobs.clear(); m_pool.waitForDone(); }

void LibraryScanner::loadFolders() {
    m_folders.clear();
    QSqlQuery q = Database::run("SELECT path FROM folders ORDER BY path");
    while (q.next()) m_folders << q.value(0).toString();
}

// ---------- folder management ----------

void LibraryScanner::addFolder(const QString &path) {
    const QString p = localPath(path);
    if (!QFileInfo(p).isDir()) { emit message(tr("Not a folder: %1").arg(p)); return; }
    for (const QString &f : m_folders) if (inside(p, f)) { emit message(tr("Already in the library: %1").arg(f)); return; }
    for (const QString &f : m_folders) if (inside(f, p)) Database::run("DELETE FROM folders WHERE path=?", {f});   // the new parent covers it
    Database::run("INSERT INTO folders(path) VALUES(?)", {p});
    loadFolders(); emit foldersChanged();
    rescan(p);
}

void LibraryScanner::removeFolder(const QString &path) {
    const QString p = localPath(path);
    m_jobs.removeIf([&](const Job &j) { return !j.loose && inside(j.scope, p); });
    if (m_running && !m_run.loose && inside(m_run.scope, p)) m_cancel = true;
    Database::run("UPDATE tracks SET missing=1 WHERE dir=? OR substr(dir,1,length(?)+1)=?||'/'", {p, p, p});
    Database::run("DELETE FROM folders WHERE path=?", {p});
    loadFolders(); emit foldersChanged(); emit libraryChanged();
}

void LibraryScanner::rescanAll() { for (const QString &f : m_folders) enqueue({f, {}, false}); }

void LibraryScanner::rescan(const QString &path) {
    const QString p = localPath(path);
    for (const QString &f : m_folders) if (inside(p, f)) { enqueue({p, {}, false}); return; }
}

void LibraryScanner::importPaths(const QVariantList &urls) {
    QStringList files;
    for (const QVariant &u : urls) {
        const QString p = localPath(u.toString());
        const QFileInfo fi(p);
        const QString ext = fi.suffix().toLower();
        if (fi.isDir()) addFolder(p);
        else if (kExt.contains(ext)) files << p;
        else if (ext == "cue")
            for (const CueTrack &t : readCue(p).tracks) {
                const QString f = resolveFile(fi.absolutePath(), t.file);
                if (!f.isEmpty() && kExt.contains(QFileInfo(f).suffix().toLower())) files << f;
            }
    }
    files.removeDuplicates();
    if (!files.isEmpty()) enqueue({QString(), files, true});
}

void LibraryScanner::cancel() { m_jobs.clear(); m_cancel = true; }

// ---------- job queue ----------

void LibraryScanner::enqueue(const Job &j) {
    if (!j.loose) for (const Job &q : m_jobs) if (!q.loose && inside(j.scope, q.scope)) return;   // already queued, or covered by a queued parent
    m_jobs << j;
    next();
}

void LibraryScanner::next() {
    if (m_running || m_jobs.isEmpty()) return;
    m_run = m_jobs.takeFirst();
    m_running = true; m_cancel = false; m_progress = m_total = 0;
    emit scanningChanged(); emit progressChanged();
    const Job j = m_run;
    m_pool.start([this, j] { runJob(j); });
}

void LibraryScanner::runJob(Job j) {   // worker thread
    QString msg; QVariantList ids; QString err;
    if (Database::open("scan", &err)) { scan(j, ids, msg); Database::close("scan"); }
    else msg = tr("Library database error: %1").arg(err);
    QMetaObject::invokeMethod(this, [this, j, ids, msg] { done(j, ids, msg); }, Qt::QueuedConnection);
}

void LibraryScanner::done(const Job &j, const QVariantList &ids, const QString &msg) {
    m_running = false; m_progress = m_total = 0;
    if (m_jobs.isEmpty()) emit scanningChanged();
    emit progressChanged();
    if (!msg.isEmpty()) emit message(msg);
    if (j.loose) emit imported(ids);
    else Database::run("INSERT OR REPLACE INTO settings(key,value) VALUES('state/lastScan', ?)", {QString::number(QDateTime::currentSecsSinceEpoch())});
    emit libraryChanged();
    emit scanFinished(j.loose ? QString() : j.scope);
    next();
}

// ---------- the scan itself (worker thread, own DB connection) ----------

void LibraryScanner::scan(const Job &j, QVariantList &outIds, QString &msg) {
    const QString C = QStringLiteral("scan");
    QSqlDatabase db = Database::get(C);
    auto run = [&](const QString &sql, const QVariantList &a = {}) { return Database::run(sql, a, C); };
    auto key = [](const QString &p, qint64 s) { return p + '|' + QString::number(s); };

    QList<QPair<QString, qint64>> folders;
    { QSqlQuery q = run("SELECT id,path FROM folders"); while (q.next()) folders << qMakePair(q.value(1).toString(), q.value(0).toLongLong()); }
    auto folderOf = [&](const QString &p) { QVariant r; for (const auto &f : folders) if (inside(p, f.first)) r = f.second; return r; };

    // 1. enumerate
    QStringList audio, cues;
    if (j.loose) {
        audio = j.files;
        QSet<QString> dirs;
        for (const QString &p : audio) dirs << QFileInfo(p).absolutePath();
        for (const QString &d : dirs) for (const QString &c : QDir(d).entryList({"*.cue"}, QDir::Files)) cues << d + '/' + c;
    } else {
        if (!QFileInfo(j.scope).isDir() || !QFileInfo(j.scope).isReadable()) { msg = tr("Folder unavailable: %1").arg(j.scope); return; }   // nothing is marked missing
        QDirIterator it(j.scope, QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString p = it.next(), ext = it.fileInfo().suffix().toLower();
            if (kExt.contains(ext)) audio << p; else if (ext == "cue") cues << p;
        }
    }
    const QSet<QString> audioSet(audio.begin(), audio.end());

    // 2. CUE sheets: audio file -> its virtual tracks (only files with 2+ tracks)
    QStringList notes;
    QHash<QString, CueUse> cueOf;
    for (const QString &cp : cues) {
        const QFileInfo cf(cp);
        const CueSheet s = readCue(cp);
        if (!s.error.isEmpty()) { notes << cf.fileName() + ": " + s.error; continue; }
        QMap<QString, QList<CueTrack>> by;
        for (const CueTrack &t : s.tracks) by[t.file] << t;
        for (auto it = by.cbegin(); it != by.cend(); ++it) {
            const QString fp = resolveFile(cf.absolutePath(), it.key());
            if (fp.isEmpty()) { notes << cf.fileName() + ": " + tr("audio file '%1' not found").arg(it.key()); continue; }
            if (it.value().size() < 2 || !audioSet.contains(fp)) continue;
            if (!cueOf.contains(fp)) cueOf.insert(fp, {cp, cf.lastModified().toSecsSinceEpoch(), s, it.value()});
        }
    }

    // 3. existing rows in scope (change detection and missing-marking)
    QHash<QString, Row> have;
    if (!j.loose) {
        QSqlQuery q = run("SELECT id,path,start_ms,mtime,size,missing,cue_path FROM tracks WHERE dir=? OR substr(dir,1,length(?)+1)=?||'/'", {j.scope, j.scope, j.scope});
        while (q.next()) have.insert(key(q.value(1).toString(), q.value(2).toLongLong()), {q.value(0).toLongLong(), q.value(3).toLongLong(), q.value(4).toLongLong(), q.value(5).toBool(), q.value(6).toString()});
    }

    QSqlQuery up(db);
    up.prepare(kUpsert);
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    int written = 0, sinceNotify = 0;
    auto put = [&](const QString &path, qint64 start, qint64 end, const QString &title, const QString &artist, const QString &album, const QString &albumArtist,
                   const QString &genre, int trackNo, int year, qint64 dur, qint64 mt, qint64 sz, const QString &hash, const QString &cue, const TagInfo &t) {
        auto opt = [](const std::optional<double> &o) { return o ? QVariant(*o) : QVariant(); };
        const QVariantList a{path, start, end, folderOf(path), QFileInfo(path).absolutePath(), title, artist, album, albumArtist, genre, trackNo, year, dur, mt, sz, hash,
                             opt(t.rgTrack), opt(t.rgAlbum), opt(t.peakTrack), opt(t.peakAlbum), cue, now};
        for (int i = 0; i < a.size(); ++i) up.bindValue(i, (a[i].metaType().id() == QMetaType::QString && a[i].toString().isNull()) ? QVariant(QStringLiteral("")) : a[i]);   // null QString would bind as SQL NULL
        if (!up.exec()) qWarning() << "Upsert failed:" << up.lastError().text() << path;
        ++written; ++sinceNotify;
    };
    auto collect = [&](const QString &p) {
        if (!j.loose) return;
        QSqlQuery q = run("SELECT id FROM tracks WHERE path=? AND missing=0 ORDER BY start_ms", {p});
        while (q.next()) outIds << q.value(0);
    };

    // 4. process files
    QSet<QString> seen;
    int n = 0, bad = 0;
    const int total = int(audio.size());
    db.transaction();
    for (const QString &p : audio) {
        if (m_cancel) break;
        if (++n % 25 == 0) QMetaObject::invokeMethod(this, [this, n, total] { m_progress = n; m_total = total; emit progressChanged(); }, Qt::QueuedConnection);
        if (written >= 200) { db.commit(); db.transaction(); written = 0; }
        if (sinceNotify >= 1000) { sinceNotify = 0; QMetaObject::invokeMethod(this, [this] { emit libraryChanged(); }, Qt::QueuedConnection); }

        const QFileInfo fi(p);
        const qint64 mt = fi.lastModified().toSecsSinceEpoch(), sz = fi.size();
        TagInfo t; bool haveTag = false;
        auto cu = cueOf.constFind(p);
        bool useCue = cu != cueOf.cend();

        if (useCue) {
            const qint64 stamp = qMax(mt, cu->cueMtime);
            bool same = true;
            for (const CueTrack &c : cu->tracks) { const Row r = have.value(key(p, c.index01)); same = same && r.id && r.mtime == stamp && r.size == sz && !r.missing && r.cue == cu->cuePath; }
            if (same) { for (const CueTrack &c : cu->tracks) seen << key(p, c.index01); collect(p); continue; }
            t = Metadata::read(p); haveTag = true;
            if (!t.ok) { ++bad; notes << fi.fileName() + ": " + tr("unreadable audio"); continue; }
            if (cu->tracks.last().index01 >= t.durationMs) { notes << QFileInfo(cu->cuePath).fileName() + ": " + tr("indexes beyond the end of the audio"); useCue = false; }
            else {
                const CueSheet &s = cu->sheet; const QList<CueTrack> &c = cu->tracks;
                for (int i = 0; i < c.size(); ++i) {
                    const CueTrack &k = c[i];
                    const qint64 end = i + 1 < c.size() ? c[i + 1].index01 : 0;   // last track plays to the end of the file
                    put(p, k.index01, end, k.title.isEmpty() ? tr("Track %1").arg(k.number) : k.title,
                        !k.performer.isEmpty() ? k.performer : (s.performer.isEmpty() ? t.artist : s.performer),
                        s.title.isEmpty() ? t.album : s.title, s.performer.isEmpty() ? t.albumArtist : s.performer,
                        s.genre.isEmpty() ? t.genre : s.genre, k.number, s.year ? s.year : t.year,
                        (end ? end : t.durationMs) - k.index01, stamp, sz, QString(), cu->cuePath, t);
                    seen << key(p, k.index01);
                }
                collect(p); continue;
            }
        }

        if (!haveTag) {
            const Row r = have.value(key(p, 0));
            if (r.id && r.mtime == mt && r.size == sz && !r.missing && r.cue.isEmpty()) { seen << key(p, 0); collect(p); continue; }
            t = Metadata::read(p);
            if (!t.ok) { ++bad; notes << fi.fileName() + ": " + tr("unreadable audio"); continue; }
        }
        const QString h = Metadata::quickHash(p);
        if (!h.isEmpty() && !have.contains(key(p, 0)) && !run("SELECT 1 FROM tracks WHERE path=? AND start_ms=0", {p}).next()) {
            QSqlQuery q = run("SELECT id,path FROM tracks WHERE hash=? AND size=? AND start_ms=0 AND end_ms=0 AND path<>?", {h, sz, p});
            while (q.next()) if (!QFile::exists(q.value(1).toString())) { run("UPDATE tracks SET path=? WHERE id=?", {p, q.value(0)}); break; }   // moved/renamed: keep the id and all user data
        }
        put(p, 0, 0, t.title.isEmpty() ? fi.completeBaseName() : t.title, t.artist, t.album, t.albumArtist, t.genre, t.trackNo, t.year, t.durationMs, mt, sz, h, QString(), t);
        seen << key(p, 0);
        collect(p);
    }

    // 5. rows whose file or virtual track is gone: flag, never delete
    if (!m_cancel && !j.loose)
        for (auto it = have.cbegin(); it != have.cend(); ++it)
            if (!it->missing && !seen.contains(it.key())) run("UPDATE tracks SET missing=1 WHERE id=? AND path=? AND start_ms=?", {it->id, it.key().section('|', 0, -2), it.key().section('|', -1).toLongLong()});   // a row re-pointed by move detection no longer matches its old path
    db.commit();
    if (!notes.isEmpty()) msg = tr("%n file(s) skipped. First: %1", nullptr, int(notes.size())).arg(notes.first());
    Q_UNUSED(bad)
}

// ---------- duplicates, history ----------

QVariantList LibraryScanner::duplicates() {
    auto members = [](const QString &where, const QVariantList &a) {
        QVariantList l;
        QSqlQuery q = Database::run("SELECT id,title,artist,album,path,duration_ms,size FROM v_tracks WHERE start_ms=0 AND end_ms=0 AND " + where + " ORDER BY path", a);
        while (q.next()) {
            QVariantMap m;
            m["id"] = q.value(0); m["title"] = q.value(1); m["artist"] = q.value(2); m["album"] = q.value(3);
            m["path"] = q.value(4); m["durationMs"] = q.value(5); m["size"] = q.value(6);
            l << m;
        }
        return l;
    };
    auto group = [](const QString &reason, const QVariantList &tracks) { QVariantMap m; m["reason"] = reason; m["tracks"] = tracks; return QVariant(m); };
    QVariantList out;
    QSqlQuery g = Database::run("SELECT hash FROM v_tracks WHERE hash<>'' AND start_ms=0 AND end_ms=0 GROUP BY hash HAVING COUNT(*)>1 LIMIT 200");
    while (g.next()) out << group(tr("Identical file content"), members("hash=?", {g.value(0)}));
    QSqlQuery t = Database::run("SELECT lower(title),lower(artist),lower(album),duration_ms/2000 FROM v_tracks WHERE title<>'' AND start_ms=0 AND end_ms=0 "
                                "GROUP BY 1,2,3,4 HAVING COUNT(*)>1 AND COUNT(DISTINCT hash)>1 LIMIT 200");
    while (t.next()) out << group(tr("Same title, artist, album and length"),
        members("lower(title)=? AND lower(artist)=? AND lower(album)=? AND duration_ms/2000=?", {t.value(0), t.value(1), t.value(2), t.value(3)}));
    return out;
}

void LibraryScanner::clearHistory() {
    QSqlDatabase db = Database::get();
    db.transaction();
    Database::run("DELETE FROM history");
    Database::run("UPDATE tracks SET play_count=0, last_played=0");
    db.commit();
    emit libraryChanged();
}
QString LibraryScanner::summary() const {
    QSqlQuery q = Database::run("SELECT COUNT(*), COALESCE(SUM(size),0) FROM v_tracks");
    qint64 n = 0, bytes = 0;
    if (q.next()) { n = q.value(0).toLongLong(); bytes = q.value(1).toLongLong(); }
    return tr("%1 tracks · %2").arg(QLocale().toString(n), QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeSIFormat));
}

QVariantMap LibraryScanner::stats() const {
    QSqlQuery q = Database::run("SELECT COUNT(*), COUNT(DISTINCT album||'|'||album_artist), COUNT(DISTINCT artist) FROM v_tracks");
    QVariantMap m;
    if (q.next()) { m["songs"] = q.value(0); m["albums"] = q.value(1); m["artists"] = q.value(2); }
    return m;
}

QString LibraryScanner::lastScanText() const {
    QSqlQuery q = Database::run("SELECT value FROM settings WHERE key='state/lastScan'");
    const qint64 ts = q.next() ? q.value(0).toLongLong() : 0;
    if (ts <= 0) return tr("No scan yet");
    const QDateTime t = QDateTime::fromSecsSinceEpoch(ts);
    const QDate today = QDate::currentDate();
    const QString time = QLocale().toString(t.time(), QLocale::ShortFormat);
    return t.date() == today ? tr("Last scan completed today at %1").arg(time)
         : t.date() == today.addDays(-1) ? tr("Last scan completed yesterday at %1").arg(time)
         : tr("Last scan completed %1").arg(QLocale().toString(t.date(), QLocale::ShortFormat));
}

void LibraryScanner::showInFolder(qint64 id) {
    QSqlQuery q = Database::run("SELECT dir FROM tracks WHERE id=?", {id});
    if (q.next()) QDesktopServices::openUrl(QUrl::fromLocalFile(q.value(0).toString()));
}

QString LibraryScanner::formatInfo(qint64 id) const {
    static QHash<qint64, QString> cache;
    if (cache.contains(id)) return cache.value(id);
    QSqlQuery q = Database::run("SELECT path FROM tracks WHERE id=?", {id});
    const QString s = q.next() ? Metadata::format(q.value(0).toString()) : QString();
    cache.insert(id, s);
    return s;
}