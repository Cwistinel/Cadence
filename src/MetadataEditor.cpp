#include "MetadataEditor.h"
#include "Database.h"

namespace {
const char *kKeys[] = {"title", "artist", "album", "albumArtist", "genre", "trackNo"};

QVariantList readRow(const QString &sql, qint64 id) {
    QVariantList v;
    QSqlQuery q = Database::run(sql, {id});
    if (q.next()) for (int i = 0; i < 6; ++i) v << q.value(i);
    return v;
}
QVariantList original(qint64 id) { return readRow("SELECT title,artist,album,album_artist,genre,track_no FROM tracks WHERE id=?", id); }
QVariantList overrides(qint64 id) { return readRow("SELECT title,artist,album,album_artist,genre,track_no FROM overrides WHERE track_id=?", id); }
}  // namespace

QVariantMap MetadataEditor::get(qint64 id) const {
    const QVariantList o = original(id), v = overrides(id);
    QVariantMap orig, cur, m;
    for (int i = 0; i < 6; ++i) {
        orig[kKeys[i]] = o.value(i);
        cur[kKeys[i]] = (v.isEmpty() || v[i].isNull()) ? o.value(i) : v[i];
    }
    m["original"] = orig; m["current"] = cur; m["overridden"] = !v.isEmpty();
    return m;
}

void MetadataEditor::save(qint64 id, const QVariantMap &f) {
    const QVariantList o = original(id), prev = overrides(id);
    if (o.isEmpty()) return;
    QVariantList nv;
    for (int i = 0; i < 6; ++i) {
        const QVariant x = f.value(kKeys[i]);
        nv << ((!f.contains(kKeys[i]) || x.toString() == o[i].toString()) ? QVariant() : x);   // unchanged fields keep following the file's tags
    }
    apply(id, nv);
    m_undo->push(tr("Metadata edited"), [this, id, prev] { apply(id, prev); });
}

void MetadataEditor::reset(qint64 id) {
    const QVariantList prev = overrides(id);
    if (prev.isEmpty()) return;
    apply(id, {});
    m_undo->push(tr("Metadata reset"), [this, id, prev] { apply(id, prev); });
}

void MetadataEditor::apply(qint64 id, const QVariantList &v) {
    bool any = false;
    for (const QVariant &x : v) any = any || !x.isNull();
    if (!any) Database::run("DELETE FROM overrides WHERE track_id=?", {id});
    else Database::run("INSERT OR REPLACE INTO overrides(track_id,title,artist,album,album_artist,genre,track_no) VALUES(?,?,?,?,?,?,?)", QVariantList{id} + v);
    m_pc->refreshTrack(id);          // queue rows, now-playing, MPRIS metadata
    emit m_lib->libraryChanged();    // album/artist groupings may have changed
}