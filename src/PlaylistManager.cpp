#include "PlaylistManager.h"
#include "Database.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QSaveFile>
#include <QSet>
#include <QUrl>

namespace {
QString local(const QString &s) { return s.startsWith("file:") ? QUrl(s).toLocalFile() : s; }
QVariantMap fail(const QString &e) { return {{"ok", false}, {"error", e}}; }

QList<qint64> order(qint64 pid) {
    QList<qint64> o;
    QSqlQuery q = Database::run("SELECT id FROM playlist_items WHERE playlist_id=? ORDER BY pos", {pid});
    while (q.next()) o << q.value(0).toLongLong();
    return o;
}
void setOrder(const QList<qint64> &o) {   // call inside a transaction
    QSqlQuery q(Database::get());
    q.prepare("UPDATE playlist_items SET pos=? WHERE id=?");
    for (int i = 0; i < o.size(); ++i) { q.bindValue(0, i); q.bindValue(1, o[i]); q.exec(); }
}
}  // namespace

PlaylistManager::PlaylistManager(PlaybackController *pc, UndoStack *u, QObject *p) : QObject(p), m_pc(pc), m_undo(u) { reload(); }

void PlaylistManager::reload() {
    m_lists.clear();
    QSqlQuery q = Database::run(
        "SELECT p.id,p.name,(SELECT COUNT(*) FROM playlist_items WHERE playlist_id=p.id),"
        "(SELECT track_id FROM playlist_items WHERE playlist_id=p.id ORDER BY pos LIMIT 1),"
        "(SELECT COALESCE(SUM(t.duration_ms),0) FROM playlist_items i JOIN tracks t ON t.id=i.track_id WHERE i.playlist_id=p.id) "
        "FROM playlists p ORDER BY lower(p.name),p.id");
    while (q.next())
        m_lists << QVariantMap{{"id", q.value(0)}, {"name", q.value(1)}, {"count", q.value(2)},
                               {"cover", q.value(3).isNull() ? QVariant(0) : q.value(3)}, {"durationMs", q.value(4)}};
    emit playlistsChanged();
}

qint64 PlaylistManager::create(const QString &name) {
    const QString n = name.trimmed().isEmpty() ? tr("New playlist") : name.trimmed();
    const qint64 id = Database::run("INSERT INTO playlists(name) VALUES(?)", {n}).lastInsertId().toLongLong();
    reload();
    return id;
}

void PlaylistManager::rename(qint64 id, const QString &name) {
    if (name.trimmed().isEmpty()) return;
    Database::run("UPDATE playlists SET name=? WHERE id=?", {name.trimmed(), id});
    reload();
}

void PlaylistManager::remove(qint64 id) { Database::run("DELETE FROM playlists WHERE id=?", {id}); reload(); }   // items cascade

int PlaylistManager::addTracks(qint64 id, const QVariantList &ids) {
    QSet<qint64> have;
    { QSqlQuery q = Database::run("SELECT track_id FROM playlist_items WHERE playlist_id=?", {id}); while (q.next()) have << q.value(0).toLongLong(); }
    QSqlQuery m = Database::run("SELECT COALESCE(MAX(pos),-1) FROM playlist_items WHERE playlist_id=?", {id});
    int pos = m.next() ? m.value(0).toInt() : -1, added = 0, dup = 0;
    QSqlDatabase db = Database::get();
    db.transaction();
    for (const QVariant &v : ids) {
        const qint64 t = v.toLongLong();
        if (have.contains(t)) { ++dup; continue; }
        QSqlQuery q = Database::run("INSERT INTO playlist_items(playlist_id,track_id,pos) SELECT ?,id,? FROM tracks WHERE id=?", {id, pos + 1, t});
        if (q.numRowsAffected() > 0) { ++pos; ++added; have << t; }
    }
    db.commit();
    if (dup) emit message(tr("%1 already in the playlist").arg(dup));
    if (added) { reload(); emit itemsChanged(id); }
    return added;
}

QVariantList PlaylistManager::items(qint64 id) const {
    QVariantList out;
    QSqlQuery q = Database::run(
        "SELECT pi.id,pi.track_id,pi.pos,t.path,COALESCE(o.title,t.title),COALESCE(o.artist,t.artist),COALESCE(o.album,t.album),t.duration_ms,t.missing,(t.start_ms>0 OR t.end_ms>0),t.favorite "
        "FROM playlist_items pi JOIN tracks t ON t.id=pi.track_id LEFT JOIN overrides o ON o.track_id=t.id WHERE pi.playlist_id=? ORDER BY pi.pos", {id});
    while (q.next()) {
        const QString path = q.value(3).toString(), title = q.value(4).toString();
        out << QVariantMap{{"itemId", q.value(0)}, {"trackId", q.value(1)}, {"pos", q.value(2)}, {"path", path},
                           {"title", title.isEmpty() ? QFileInfo(path).completeBaseName() : title}, {"artist", q.value(5)}, {"album", q.value(6)},
                           {"durationMs", q.value(7)}, {"missing", q.value(8).toBool()}, {"virtual", q.value(9).toBool()}, {"favorite", q.value(10).toBool()}};
    }
    return out;
}

void PlaylistManager::removeItems(qint64 id, const QVariantList &itemIds) {
    QSet<qint64> rm;
    for (const QVariant &v : itemIds) rm << v.toLongLong();
    QHash<qint64, qint64> trackOf;
    { QSqlQuery q = Database::run("SELECT id,track_id FROM playlist_items WHERE playlist_id=?", {id}); while (q.next()) trackOf.insert(q.value(0).toLongLong(), q.value(1).toLongLong()); }
    QList<qint64> keep;
    QList<QPair<int, qint64>> gone;   // original index, track id (ascending index)
    const QList<qint64> cur = order(id);
    for (int i = 0; i < cur.size(); ++i) { if (rm.contains(cur[i])) gone << qMakePair(i, trackOf.value(cur[i])); else keep << cur[i]; }
    if (gone.isEmpty()) return;
    QSqlDatabase db = Database::get();
    db.transaction();
    for (qint64 r : rm) Database::run("DELETE FROM playlist_items WHERE id=? AND playlist_id=?", {r, id});
    setOrder(keep);
    db.commit();
    reload(); emit itemsChanged(id);
    m_undo->push(tr("Removed from playlist"), [this, id, gone] { restoreItems(id, gone); });
}

void PlaylistManager::restoreItems(qint64 id, const QList<QPair<int, qint64>> &gone) {
    if (!Database::run("SELECT 1 FROM playlists WHERE id=?", {id}).next()) return;   // playlist deleted meanwhile
    QSqlDatabase db = Database::get();
    db.transaction();
    QList<qint64> o = order(id);
    for (const auto &g : gone) {   // ascending original indexes: each insert lands exactly where the item used to be
        const qint64 nid = Database::run("INSERT INTO playlist_items(playlist_id,track_id,pos) VALUES(?,?,?)", {id, g.second, o.size()}).lastInsertId().toLongLong();
        if (nid > 0) o.insert(qMin<qsizetype>(g.first, o.size()), nid);
    }
    setOrder(o);
    db.commit();
    reload(); emit itemsChanged(id);
}

void PlaylistManager::move(qint64 id, int from, int to) {
    QList<qint64> o = order(id);
    if (from == to || from < 0 || to < 0 || from >= o.size() || to >= o.size()) return;
    o.move(from, to);
    QSqlDatabase db = Database::get();
    db.transaction(); setOrder(o); db.commit();
    emit itemsChanged(id);
}

void PlaylistManager::play(qint64 id, int start) {
    QVariantList ids;
    QSqlQuery q = Database::run("SELECT track_id FROM playlist_items WHERE playlist_id=? ORDER BY pos", {id});
    while (q.next()) ids << q.value(0);
    m_pc->playTracks(ids, start);
}

void PlaylistManager::enqueue(qint64 id) {
    QVariantList ids;
    QSqlQuery q = Database::run("SELECT track_id FROM playlist_items WHERE playlist_id=? ORDER BY pos", {id});
    while (q.next()) ids << q.value(0);
    m_pc->enqueue(ids);
}

// ---------- M3U / M3U8 ----------

QVariantMap PlaylistManager::importM3u(const QString &url) {
    const QString path = local(url);
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly) || f.size() > 20 * 1024 * 1024) return fail(tr("Can't read %1").arg(path));
    const QByteArray raw = f.readAll();
    QString text = QString::fromUtf8(raw);
    if (text.contains(QChar::ReplacementCharacter)) text = QString::fromLatin1(raw);   // legacy .m3u
    if (text.startsWith(QChar(0xFEFF))) text.remove(0, 1);

    const QDir base(QFileInfo(path).absolutePath());
    QVariantList ids; QSet<qint64> seen; QStringList missing, unknown; int dup = 0;
    for (QString line : text.split('\n')) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        QString p = line.startsWith("file:") ? QUrl(line).toLocalFile() : line;
        if (!p.contains('/')) p.replace('\\', '/');   // Windows-made playlists
        p = QDir::cleanPath(QDir::isAbsolutePath(p) ? p : base.absoluteFilePath(p));
        QSqlQuery q = Database::run("SELECT id FROM tracks WHERE path=? AND missing=0 ORDER BY start_ms LIMIT 1", {p});
        if (q.next()) { const qint64 id = q.value(0).toLongLong(); if (seen.contains(id)) ++dup; else { seen << id; ids << id; } }
        else (QFileInfo::exists(p) ? unknown : missing) << p;
    }
    if (ids.isEmpty()) {
        QVariantMap r = fail(tr("No playable entries found")); r["missing"] = missing; r["unknown"] = unknown;
        return r;
    }
    const qint64 pid = create(QFileInfo(path).completeBaseName());
    const int added = addTracks(pid, ids);
    emit message(tr("Imported %1 tracks. %2 missing, %3 not in the library.").arg(added).arg(missing.size()).arg(unknown.size()));
    return {{"ok", true}, {"id", pid}, {"added", added}, {"duplicates", dup}, {"missing", missing}, {"unknown", unknown}};
}

bool PlaylistManager::exists(const QString &url) const { return QFileInfo::exists(local(url)); }

QVariantMap PlaylistManager::exportM3u(qint64 id, const QString &url, bool overwrite, bool relative) {
    const QString dest = local(url);
    if (QFileInfo::exists(dest) && !overwrite) return fail("exists");
    const QDir base(QFileInfo(dest).absolutePath());
    QByteArray out = "#EXTM3U\n";
    int written = 0, skipped = 0;
    for (const QVariant &v : items(id)) {
        const QVariantMap m = v.toMap();
        if (m["virtual"].toBool()) { ++skipped; continue; }   // M3U cannot address a CUE sub-range
        const QString p = m["path"].toString(), artist = m["artist"].toString(), title = m["title"].toString();
        out += "#EXTINF:" + QByteArray::number(m["durationMs"].toLongLong() / 1000) + ',' + (artist.isEmpty() ? title : artist + " - " + title).toUtf8() + '\n'
             + (relative ? base.relativeFilePath(p) : p).toUtf8() + '\n';
        ++written;
    }
    QSaveFile f(dest);   // temp file + atomic rename: a failed overwrite leaves the old file intact
    if (!f.open(QIODevice::WriteOnly) || f.write(out) != out.size() || !f.commit()) return fail(tr("Can't write %1").arg(dest));
    return {{"ok", true}, {"written", written}, {"skipped", skipped}};
}