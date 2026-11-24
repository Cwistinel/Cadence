#pragma once
#include <QQuickImageProvider>

// "image://icons/<name>?c=rrggbb": renders the Figma SVG assets in assets/icons/ recolored to the given color.
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;
};