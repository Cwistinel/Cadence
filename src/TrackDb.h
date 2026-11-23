#pragma once
#include "Database.h"
#include "Track.h"

namespace TrackDb {
constexpr const char *kCols = "id,path,start_ms,end_ms,title,artist,album,album_artist,genre,track_no,year,duration_ms,rg_track,rg_album,peak_track,peak_album,favorite";

inline Track fromRow(const QSqlQuery &q) {   // column order = kCols
    Track t;
    t.id = q.value(0).toLongLong(); t.path = q.value(1).toString();
    t.startMs = q.value(2).toLongLong(); t.endMs = q.value(3).toLongLong();
    t.title = q.value(4).toString(); t.artist = q.value(5).toString(); t.album = q.value(6).toString();
    t.albumArtist = q.value(7).toString(); t.genre = q.value(8).toString();
    t.trackNo = q.value(9).toInt(); t.year = q.value(10).toInt(); t.durationMs = q.value(11).toLongLong();
    t.hasRgTrack = !q.isNull(12); t.rgTrack = q.value(12).toDouble();
    t.hasRgAlbum = !q.isNull(13); t.rgAlbum = q.value(13).toDouble();
    t.peakTrack = q.isNull(14) ? 1.0 : q.value(14).toDouble();
    t.peakAlbum = q.isNull(15) ? 1.0 : q.value(15).toDouble();
    t.favorite = q.value(16).toBool();
    return t;
}

// Loads in the given order; ids that are unknown or marked missing are skipped.
inline QList<Track> loadMany(const QList<qint64> &ids) {
    QList<Track> out; out.reserve(ids.size());
    QSqlQuery q(Database::get());
    q.prepare(QStringLiteral("SELECT ") + kCols + " FROM v_tracks WHERE id=?");
    for (qint64 id : ids) { q.bindValue(0, id); if (q.exec() && q.next()) out << fromRow(q); }
    return out;
}

inline Track load(qint64 id) { const auto v = loadMany({id}); return v.isEmpty() ? Track{} : v.first(); }
}  // namespace TrackDb