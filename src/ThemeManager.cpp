#include "ThemeManager.h"
#include "ArtworkManager.h"
#include <QFile>
#include <QHash>
#include <QImage>
#include <QtConcurrent>
#include <cmath>
#include <utility>

namespace {
double lum(const QColor &c) {
    auto f = [](double v) { return v <= 0.03928 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(c.redF()) + 0.7152 * f(c.greenF()) + 0.0722 * f(c.blueF());
}
double contrast(const QColor &a, const QColor &b) { double x = lum(a), y = lum(b); if (x < y) std::swap(x, y); return (x + 0.05) / (y + 0.05); }
QColor mix(const QColor &a, const QColor &b, double t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t, a.blueF() + (b.blueF() - a.blueF()) * t);
}
QColor withContrast(QColor c, const QColor &bg, double min) {   // keep the hue, move lightness away from bg until readable
    const bool lighten = lum(bg) < 0.5;
    const float h = c.hslHueF() < 0 ? 0.f : c.hslHueF(), s = c.hslSaturationF();
    float l = c.lightnessF();
    for (int i = 0; i < 30 && contrast(c, bg) < min; ++i) { l = lighten ? qMin(1.f, l + 0.04f) : qMax(0.f, l - 0.04f); c = QColor::fromHslF(h, s, l); }
    return c;
}

// Weighted 4-bit color histogram on a 48px thumbnail: saturated, mid-brightness pixels count most; near-black/white are ignored.
QColor dominant(const QImage &src) {
    const QImage im = src.scaled(48, 48, Qt::KeepAspectRatio, Qt::FastTransformation).convertToFormat(QImage::Format_RGB32);
    struct Bin { double w = 0, r = 0, g = 0, b = 0; };
    QList<Bin> bins(4096);
    double ar = 0, ag = 0, ab = 0; int n = 0;
    for (int y = 0; y < im.height(); ++y)
        for (int x = 0; x < im.width(); ++x) {
            const QColor c(im.pixel(x, y));
            ar += c.red(); ag += c.green(); ab += c.blue(); ++n;
            const double s = c.hsvSaturationF(), v = c.valueF();
            if (v < 0.15 || (s < 0.12 && v > 0.9)) continue;
            Bin &b = bins[((c.red() >> 4) << 8) | ((c.green() >> 4) << 4) | (c.blue() >> 4)];
            const double w = 0.25 + s;
            b.w += w; b.r += c.red() * w; b.g += c.green() * w; b.b += c.blue() * w;
        }
    const Bin *best = &bins[0];
    for (const Bin &b : bins) if (b.w > best->w) best = &b;
    if (best->w > 0) return QColor(int(best->r / best->w), int(best->g / best->w), int(best->b / best->w));
    return n ? QColor(int(ar / n), int(ag / n), int(ab / n)) : QColor();   // black/white art: plain average
}
}  // namespace

ThemeManager::ThemeManager(PlaybackController *pc, Settings *s, QObject *p) : QObject(p), m_pc(pc), m_set(s) {
    connect(pc, &PlaybackController::trackChanged, this, &ThemeManager::onTrack);
    connect(s, &Settings::revisionChanged, this, &ThemeManager::recompute);
    recompute();
    onTrack();
}

QColor ThemeManager::extract(qint64 id) {
    const QString key = ArtworkManager::key(id);
    if (key.isEmpty()) return {};
    const QString f = ArtworkManager::cacheDir() + '/' + key + ".col";
    if (QFile in(f); in.open(QIODevice::ReadOnly)) { const QString s = QString::fromLatin1(in.readAll()).trimmed(); return s == "none" ? QColor() : QColor(s); }
    const QImage img = ArtworkManager::image(id);
    const QColor c = img.isNull() ? QColor() : dominant(img);
    if (QFile out(f); out.open(QIODevice::WriteOnly)) out.write(c.isValid() ? c.name().toLatin1() : QByteArray("none"));
    return c;
}

void ThemeManager::onTrack() {   // trackChanged also fires for favorite/metadata edits: only a different track id matters
    const qint64 id = m_pc->currentTrack().id;
    if (id == m_id) return;
    m_id = id;
    if (!id) { m_art = QColor(); recompute(); return; }
    (void)QtConcurrent::run([this, id] {
        const QColor c = extract(id);
        QMetaObject::invokeMethod(this, [this, id, c] { if (id == m_id) { m_art = c; recompute(); } }, Qt::QueuedConnection);   // stale results are dropped
    });
}

void ThemeManager::recompute() {
    const QString m = mode();
    const QColor base(0x2E, 0x6F, 0xD8);                 // fixed blue accent, a bit darker than before
    Palette p;
    p.dark = m != "light";
    p.bg = m == "light" ? QColor(0xFA, 0xFA, 0xFA) : QColor(0x1E, 0x1F, 0x22);   // dark gray for Automatic and Dark
    p.text = p.dark ? QColor(0xF5, 0xF5, 0xF5) : QColor(0x1A, 0x1A, 0x1A);
    p.subtext = mix(p.text, p.bg, 0.4);
    p.surface = mix(p.bg, p.text, p.dark ? 0.07 : 0.05);
    p.accent = withContrast(base, p.bg, 3.0);
    p.onAccent = contrast(Qt::black, p.accent) >= contrast(Qt::white, p.accent) ? QColor(Qt::black) : QColor(Qt::white);
    m_p = p;
    emit themeChanged();
}