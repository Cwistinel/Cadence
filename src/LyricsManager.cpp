#include "LyricsManager.h"
#include "Database.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QUrl>
#include <algorithm>
#include <taglib/fileref.h>
#include <taglib/tfile.h>
#include <taglib/tpropertymap.h>

namespace {
QString local(const QString &s) { return s.startsWith("file:") ? QUrl(s).toLocalFile() : s; }

QString readText(const QString &p) {
    QFile f(p);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 2 * 1024 * 1024) return {};
    const QByteArray b = f.readAll();
    QString s = QString::fromUtf8(b);
    if (s.contains(QChar::ReplacementCharacter)) s = QString::fromLatin1(b);
    if (s.startsWith(QChar(0xFEFF))) s.remove(0, 1);
    return s;
}

QString embedded(const QString &path) {   // USLT / Vorbis LYRICS via TagLib's property map
    const TagLib::FileRef f(QFile::encodeName(path).constData(), false);
    if (f.isNull() || !f.file()) return {};
    const TagLib::PropertyMap p = f.file()->properties();
    for (const char *k : {"LYRICS", "UNSYNCEDLYRICS"}) {
        const auto it = p.find(k);
        if (it != p.end() && !it->second.isEmpty()) return QString::fromUtf8(it->second.front().toCString(true));
    }
    return {};
}

QString stamp(qint64 ms) {   // lossless: centiseconds when exact, otherwise milliseconds
    ms = qMax<qint64>(0, ms);
    const QString mm = QString("%1").arg(ms / 60000, 2, 10, QChar('0')), ss = QString("%1").arg(ms / 1000 % 60, 2, 10, QChar('0'));
    const int r = int(ms % 1000);
    return r % 10 ? QString("[%1:%2.%3]").arg(mm, ss).arg(r, 3, 10, QChar('0')) : QString("[%1:%2.%3]").arg(mm, ss).arg(r / 10, 2, 10, QChar('0'));
}
}  // namespace

LyricsManager::LyricsManager(PlaybackController *pc, UndoStack *u, QObject *p) : QObject(p), m_pc(pc), m_undo(u) {
    connect(pc, &PlaybackController::trackChanged, this, [this] { if (m_pc->currentTrack().id != m_id) reload(); });
    connect(pc, &PlaybackController::positionChanged, this, &LyricsManager::onPosition);
    reload();
}

// ---------- parsing (milliseconds everywhere) ----------

LyricsDoc LyricsManager::parse(const QString &in) {
    static const QRegularExpression ts(R"(\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\])");
    static const QRegularExpression meta(R"(^\[([A-Za-z#]+):(.*)\]$)");
    static const QRegularExpression word(R"(<\d+:\d{1,2}(?:[.:]\d{1,3})?>)");   // enhanced-LRC word times
    LyricsDoc d;
    QList<LyricLine> plain;
    qint64 offset = 0;
    for (QString line : in.split('\n')) {
        line = line.trimmed();
        QList<qint64> times;
        while (line.startsWith('[')) {
            const auto m = ts.match(line, 0, QRegularExpression::NormalMatch, QRegularExpression::AnchoredMatchOption);
            if (!m.hasMatch()) break;
            const QString f = m.captured(3);
            times << (m.captured(1).toLongLong() * 60 + m.captured(2).toInt()) * 1000 + (f.isEmpty() ? 0 : f.toInt() * (f.size() == 1 ? 100 : f.size() == 2 ? 10 : 1));
            line = line.mid(m.capturedLength()).trimmed();
        }
        if (times.isEmpty()) {
            const auto m = meta.match(line);
            if (!m.hasMatch()) plain << LyricLine{-1, line};
            else if (m.captured(1).toLower() == "offset") offset = m.captured(2).trimmed().toLongLong();   // positive = lyrics appear earlier
            else d.meta << line;
            continue;
        }
        line.remove(word);
        for (qint64 t : times) d.lines << LyricLine{t, line.trimmed()};
    }
    if (!d.lines.isEmpty()) {
        d.synced = true;                                                 // un-stamped lines of a synced file have no timeline: dropped
        if (offset) for (LyricLine &l : d.lines) l.ms = qMax<qint64>(0, l.ms - offset);
        std::stable_sort(d.lines.begin(), d.lines.end(), [](const LyricLine &a, const LyricLine &b) { return a.ms < b.ms; });
    } else {
        while (!plain.isEmpty() && plain.first().text.isEmpty()) plain.removeFirst();
        while (!plain.isEmpty() && plain.last().text.isEmpty()) plain.removeLast();
        d.lines = plain;
    }
    return d;
}

QString LyricsManager::format(const LyricsDoc &d) {
    QStringList out = d.meta;
    for (const LyricLine &l : d.lines) out << (d.synced ? stamp(l.ms) + l.text : l.text);
    return out.join('\n');
}

QString LyricsManager::shift(const QString &text, qint64 delta) const {
    LyricsDoc d = parse(text);
    if (!d.synced) return text;
    for (LyricLine &l : d.lines) l.ms = qMax<qint64>(0, l.ms + delta);
    return format(d);
}

QVariantList LyricsManager::parseText(const QString &text) const {
    QVariantList out;
    for (const LyricLine &l : parse(text).lines) out << QVariantMap{{"ms", l.ms}, {"text", l.text}};
    return out;
}

QString LyricsManager::compose(const QVariantList &lines) const {
    LyricsDoc d;
    for (const QVariant &v : lines) { const QVariantMap m = v.toMap(); d.lines << LyricLine{m.value("ms", -1).toLongLong(), m.value("text").toString()}; d.synced = d.synced || d.lines.last().ms >= 0; }
    return format(d);
}

QString LyricsManager::readFile(const QString &p) const { return readText(local(p)); }

// ---------- lookup ----------

QString LyricsManager::findFile(const Track &t) const {
    const QFileInfo fi(t.path);
    QStringList want;
    if (!t.isVirtual()) want << fi.completeBaseName();   // a CUE file's own .lrc would carry whole-album timestamps
    if (!t.title.isEmpty()) {
        if (!t.artist.isEmpty()) want << t.artist + " - " + t.title;
        want << t.title;
        if (t.trackNo > 0) want << QString("%1 - %2").arg(t.trackNo, 2, 10, QChar('0')).arg(t.title) << QString("%1. %2").arg(t.trackNo, 2, 10, QChar('0')).arg(t.title);
    }
    QList<QFileInfo> lrc;
    for (const QFileInfo &f : QDir(fi.absolutePath()).entryInfoList(QDir::Files)) if (f.suffix().compare("lrc", Qt::CaseInsensitive) == 0) lrc << f;
    for (const QString &w : want) for (const QFileInfo &f : lrc) if (f.completeBaseName().compare(w, Qt::CaseInsensitive) == 0) return f.absoluteFilePath();
    return {};
}

void LyricsManager::reload() {
    const Track &t = m_pc->currentTrack();
    m_id = t.id; m_raw.clear(); m_source = "none";
    if (m_id) {
        QSqlQuery q = Database::run("SELECT content FROM lyrics WHERE track_id=?", {m_id});
        if (q.next()) { m_raw = q.value(0).toString(); m_source = "edited"; }
        else if (const QString f = findFile(t); !f.isEmpty()) { m_raw = readText(f); m_source = "file"; }
        else if (!t.isVirtual()) { m_raw = embedded(t.path); m_source = "embedded"; }
    }
    if (m_raw.trimmed().isEmpty()) { m_raw.clear(); m_source = "none"; }
    m_doc = parse(m_raw);
    m_lines.clear();
    for (const LyricLine &l : m_doc.lines) m_lines << QVariantMap{{"ms", l.ms}, {"text", l.text}};
    m_line = -1;
    emit lyricsChanged();
    onPosition(m_pc->position());
    emit currentLineChanged();
}

void LyricsManager::onPosition(qint64 ms) {   // binary search on the real engine position; emits only when the line changes
    if (!m_doc.synced) return;
    const auto it = std::upper_bound(m_doc.lines.begin(), m_doc.lines.end(), ms, [](qint64 v, const LyricLine &l) { return v < l.ms; });
    const int i = int(it - m_doc.lines.begin()) - 1;
    if (i != m_line) { m_line = i; emit currentLineChanged(); }
}

// ---------- editing (stored in SQLite; .lrc files and audio are never written) ----------

void LyricsManager::save(const QString &text) {
    if (!m_id) return;
    const qint64 id = m_id;
    QSqlQuery q = Database::run("SELECT content FROM lyrics WHERE track_id=?", {id});
    const QVariant prev = q.next() ? q.value(0) : QVariant();
    store(id, text.trimmed().isEmpty() ? QVariant() : QVariant(text));
    m_undo->push(tr("Lyrics edited"), [this, id, prev] { store(id, prev); });
}

void LyricsManager::store(qint64 id, const QVariant &content) {
    if (content.isNull()) Database::run("DELETE FROM lyrics WHERE track_id=?", {id});
    else Database::run("INSERT OR REPLACE INTO lyrics(track_id,content) VALUES(?,?)", {id, content});
    if (id == m_id) reload();
}