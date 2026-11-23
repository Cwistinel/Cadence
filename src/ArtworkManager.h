#pragma once
#include <QImage>
#include <QQuickImageProvider>

namespace ArtworkManager {
QString cacheDir();               // ~/.cache/cadence/art
QString key(qint64 trackId);      // cache key (empty for unknown ids)
QImage image(qint64 trackId);     // cached/resized cover, null if none. Thread-safe (own DB connection per thread).
}

// QML: Image { source: "image://art/" + trackId; sourceSize: Qt.size(256, 256) }  (falls back to a placeholder)
class ArtProvider : public QQuickImageProvider {
public:
    ArtProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;
};