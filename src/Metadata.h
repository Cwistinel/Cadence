#pragma once
#include <QByteArray>
#include <QString>
#include <optional>

struct TagInfo {
    bool ok = false;                                     // false = not playable audio
    QString title, artist, album, albumArtist, genre;
    int trackNo = 0, year = 0;
    qint64 durationMs = 0;
    std::optional<double> rgTrack, rgAlbum, peakTrack, peakAlbum;
};

namespace Metadata {
TagInfo read(const QString &path);        // TagLib first; GStreamer Discoverer for what TagLib can't parse (e.g. AMR)
QByteArray cover(const QString &path);    // embedded cover bytes (empty if none); used by the ArtworkManager
QString quickHash(const QString &path);   // SHA-1 of size + first and last 64 KiB
}