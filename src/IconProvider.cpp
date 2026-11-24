#include "IconProvider.h"
#include <QFile>
#include <QPainter>
#include <QRegularExpression>
#include <QSvgRenderer>

QImage IconProvider::requestImage(const QString &id, QSize *size, const QSize &req) {
    const QString name = id.section('?', 0, 0), color = QStringLiteral("#") + id.section('?', 1).mid(2);   // "name?c=rrggbb"
    if (name.isEmpty() || name.contains('/')) return {};
    QFile f(":/assets/icons/" + name + ".svg");
    if (!f.open(QIODevice::ReadOnly)) return {};
    // Figma exports hard-code (or var()-wrap) their colors: swap every painted fill/stroke for the requested color.
    static const QRegularExpression paint(R"re(\b(fill|stroke)="(?!none")(?!url\()[^"]*")re");
    QString svg = QString::fromUtf8(f.readAll());
    svg.replace(paint, QStringLiteral("\\1=\"") + color + QLatin1Char('"'));
    QSvgRenderer r(svg.toUtf8());
    if (!r.isValid()) return {};
    QSize def = r.defaultSize();
    if (def.isEmpty()) def = QSize(20, 20);
    const QSize out = def.scaled(req.isValid() ? req : def, Qt::KeepAspectRatio);
    QImage img(out, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    r.render(&p);
    p.end();
    if (size) *size = out;
    return img;
}