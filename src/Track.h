#pragma once
#include <QString>

struct Track {
    qint64 id = 0;
    QString path, title, artist, album, albumArtist, genre;
    int trackNo = 0, year = 0;
    qint64 startMs = 0, endMs = 0, durationMs = 0;   // start/end > 0 => CUE virtual track
    double rgTrack = 0, rgAlbum = 0, peakTrack = 1, peakAlbum = 1;
    bool hasRgTrack = false, hasRgAlbum = false, favorite = false;
    bool isVirtual() const { return startMs > 0 || endMs > 0; }
};