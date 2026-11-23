#include "WavySeekbar.h"
#include <QMouseEvent>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <QtMath>
#include <cmath>

namespace {
constexpr int kPts = 200, kCapS = 10, kCapV = 4 * (kCapS + 1), kRingS = 40, kRingV = 2 * (kRingS + 1);
constexpr qreal kTrack = 4.5, kThumbR = 7.5, kHalo = 3.5, kPad = 14, kBelow = 14;   // px; kBelow = space under the bar line

QColor shift(const QColor &c, float dv, float ds) {   // LastWave's shiftTonal: HSV value shift, saturation scale
    float h, s, v, a; c.getHsvF(&h, &s, &v, &a);
    const float s0 = s;
    s = qBound(s0 > 0.05f ? 0.15f : 0.f, s * ds, 1.f);
    v = qBound(0.25f, v + dv, 1.f);
    return QColor::fromHsvF(h < 0 ? 0.f : h, s, v);
}
QColor rotate(const QColor &c, float deg) {
    float h, s, v, a; c.getHsvF(&h, &s, &v, &a);
    h = h < 0 ? 0.f : float(std::fmod(h * 360.f + deg + 360.f, 360.f) / 360.f);
    return QColor::fromHsvF(h, s, v);
}
QColor lerp(const QColor &a, const QColor &b, qreal t) {
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t, a.blueF() + (b.blueF() - a.blueF()) * t);
}
void put(QSGGeometry::ColoredPoint2D &v, float x, float y, const QColor &c, float alpha) {   // vertex colors are premultiplied
    v.set(x, y, uchar(c.red() * alpha), uchar(c.green() * alpha), uchar(c.blue() * alpha), uchar(alpha * 255));
}
float smoother(float t) { t = qBound(0.f, t, 1.f); return t * t * t * (t * (t * 6 - 15) + 10); }

QSGGeometryNode *makeNode(int vertices) {
    auto *g = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), vertices);
    g->setDrawingMode(QSGGeometry::DrawTriangleStrip);
    auto *n = new QSGGeometryNode;
    n->setGeometry(g); n->setMaterial(new QSGVertexColorMaterial);
    n->setFlags(QSGNode::OwnsGeometry | QSGNode::OwnsMaterial);
    return n;
}
// Capsule (circle when x0 == x1) with a horizontal two-color gradient.
void capsule(QSGGeometryNode *n, qreal x0, qreal x1, qreal cy, qreal r, const QColor &c0, const QColor &c1, float a0, float a1) {
    auto *v = n->geometry()->vertexDataAsColoredPoint2D();
    const qreal span = qMax<qreal>(1, x1 - x0 + 2 * r);
    auto col = [&](qreal x, QColor &c, float &a) { const qreal t = qBound<qreal>(0, (x - (x0 - r)) / span, 1); c = lerp(c0, c1, t); a = float(a0 + (a1 - a0) * t); };
    QColor c; float a; int k = 0;
    for (int i = 0; i <= kCapS; ++i) { const qreal t = M_PI_2 * i / kCapS, x = x0 - r * qCos(t); col(x, c, a);
        put(v[k++], x, cy - r * qSin(t), c, a); put(v[k++], x, cy + r * qSin(t), c, a); }
    for (int i = kCapS; i >= 0; --i) { const qreal t = M_PI_2 * i / kCapS, x = x1 + r * qCos(t); col(x, c, a);
        put(v[k++], x, cy - r * qSin(t), c, a); put(v[k++], x, cy + r * qSin(t), c, a); }
    n->markDirty(QSGNode::DirtyGeometry);
}
void ring(QSGGeometryNode *n, qreal cx, qreal cy, qreal r, qreal w, const QColor &c, float alpha) {
    auto *v = n->geometry()->vertexDataAsColoredPoint2D();
    for (int i = 0; i <= kRingS; ++i) {
        const qreal t = 2 * M_PI * i / kRingS, co = qCos(t), si = qSin(t);
        put(v[2 * i], cx + (r + w / 2) * co, cy + (r + w / 2) * si, c, alpha);
        put(v[2 * i + 1], cx + (r - w / 2) * co, cy + (r - w / 2) * si, c, alpha);
    }
    n->markDirty(QSGNode::DirtyGeometry);
}

struct Root : QSGNode {
    QSGGeometryNode *track, *wave[3], *prog, *halo, *core, *rim;
    Root() {
        track = add(kCapV);
        for (auto &w : wave) w = add(kPts * 2);
        prog = add(kCapV); halo = add(kCapV); core = add(kCapV); rim = add(kRingV);
    }
    QSGGeometryNode *add(int n) { auto *g = makeNode(n); appendChildNode(g); return g; }
};

// wavelength px, amplitude px, phase period s, phase offset, stroke px
struct Wave { qreal lambda, amp, period, offset, thick; };
constexpr Wave kW[3] = {{160, 13, 2.4, 2.2, 1.0}, {125, 10, 1.8, 1.2, 1.2}, {95, 7.5, 1.3, 0.0, 1.6}};
}  // namespace

WavySeekbar::WavySeekbar(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
    setAcceptedMouseButtons(Qt::LeftButton);
    m_stamp.start(); m_frame.start();
    m_tick.setInterval(33);                              // slow rolling waves look the same at 30 fps
    connect(&m_tick, &QTimer::timeout, this, [this] { update(); });
}

void WavySeekbar::syncTimer() {
    const bool on = m_playing && isVisible() && window();
    if (on && !m_tick.isActive()) m_tick.start(); else if (!on) m_tick.stop();
    update();
}

void WavySeekbar::setPosition(qreal v) { if (qFuzzyCompare(v + 1, m_pos + 1)) return; m_pos = v; m_stamp.restart(); emit positionChanged(); update(); }
void WavySeekbar::setDuration(qreal v) { if (qFuzzyCompare(v + 1, m_dur + 1)) return; m_dur = v; emit durationChanged(); update(); }
void WavySeekbar::setAccent(const QColor &c) { if (c == m_accent) return; m_accent = c; emit accentChanged(); update(); }
void WavySeekbar::setTrackColor(const QColor &c) { if (c == m_track) return; m_track = c; emit trackColorChanged(); update(); }
void WavySeekbar::setPlaying(bool v) {
    if (v == m_playing) return;
    m_pos += m_playing ? m_stamp.elapsed() : 0; m_stamp.restart();
    m_playing = v; emit playingChanged(); syncTimer();
}

void WavySeekbar::itemChange(ItemChange c, const ItemChangeData &d) {
    QQuickItem::itemChange(c, d);
    if (c == ItemVisibleHasChanged || c == ItemSceneChange) syncTimer();
}

void WavySeekbar::dragTo(qreal x) {
    const qreal w = qMax<qreal>(1, width() - 2 * kPad);
    m_dragMs = qBound<qreal>(0, (x - kPad) / w, 1) * m_dur;
    emit scrubPositionChanged(); update();
}
void WavySeekbar::mousePressEvent(QMouseEvent *e) { m_drag = true; setKeepMouseGrab(true); emit scrubbingChanged(); dragTo(e->position().x()); }
void WavySeekbar::mouseMoveEvent(QMouseEvent *e) { if (m_drag) dragTo(e->position().x()); }
void WavySeekbar::mouseReleaseEvent(QMouseEvent *e) {
    if (!m_drag) return;
    dragTo(e->position().x());
    m_drag = false; setKeepMouseGrab(false);
    m_pos = m_dragMs; m_stamp.restart();                 // hold the thumb until the engine reports the new position
    emit seekRequested(m_dragMs); emit scrubbingChanged(); update();
}

QSGNode *WavySeekbar::updatePaintNode(QSGNode *old, UpdatePaintNodeData *) {
    auto *root = static_cast<Root *>(old);
    if (!root) root = new Root;

    qreal dt = m_frame.restart() * 1e-3;
    if (dt > 0.1 || dt < 0) dt = 0.033;
    if (m_tick.isActive() && !m_drag) m_clock = std::fmod(m_clock + dt, 93.6);   // 93.6 s = whole number of all three periods
    const qreal target = m_drag ? 1 : 0;                                          // waves flatten while scrubbing (180 ms)
    if (m_flat != target) { m_flat = target > m_flat ? qMin(target, m_flat + dt / 0.18) : qMax(target, m_flat - dt / 0.18); update(); }

    const qreal x0 = kPad, x1 = qMax(x0 + 8, width() - kPad), cy = height() - kBelow, half = kTrack / 2, topY = cy - half;
    qreal cur = m_drag ? m_dragMs : m_pos + (m_playing ? m_stamp.elapsed() : 0);
    if (m_dur > 0) cur = qBound<qreal>(0, cur, m_dur);
    const qreal xp = x0 + (m_dur > 0 ? cur / m_dur : 0) * (x1 - x0), played = xp - x0;

    // Palette: primary = accent; secondary/tertiary are hue-shifted neighbours (the app only has one art color).
    const QColor p = m_accent, s = rotate(m_accent, -22), t = rotate(m_accent, 28);
    const QColor L1[2] = {shift(t, .18f, .85f), shift(t, -.06f, 1.15f)}, L2[2] = {shift(s, -.08f, 1.15f), shift(s, .18f, .85f)}, L3[2] = {shift(p, .20f, .90f), shift(p, -.05f, 1.15f)};
    const float A1[2] = {.40f, .30f}, A2[2] = {.68f, .58f}, A3[2] = {.95f, .88f};
    const QColor *C[3] = {L1, L2, L3};
    const float *A[3] = {A1, A2, A3};

    capsule(root->track, x0, x1, cy, half, m_track, m_track, m_track.alphaF(), m_track.alphaF());
    capsule(root->prog, x0, xp, cy, half, L3[0], L3[1], 1.f, 1.f);

    const qreal transition = qMin<qreal>(44, played * 0.48), inv = transition > 0 ? 1 / transition : 0;
    for (int i = 0; i < 3; ++i) {
        const Wave &W = kW[i];
        const qreal amp = W.amp + (1.2 - W.amp) * m_flat, k = 2 * M_PI / W.lambda;
        const qreal cyc = m_clock / W.period, phase = (cyc - std::floor(cyc)) * 2 * M_PI + W.offset;
        qreal xs[kPts], ys[kPts];
        for (int j = 0; j < kPts; ++j) {
            const qreal x = played * j / (kPts - 1);                      // distance from the bar start
            const qreal env = inv > 0 ? smoother(float(x * inv)) * smoother(float((played - x) * inv)) : 1;
            xs[j] = x0 + x; ys[j] = topY - (0.5 + 0.5 * qSin(x * k - phase)) * amp * env;
        }
        auto *v = root->wave[i]->geometry()->vertexDataAsColoredPoint2D();
        for (int j = 0; j < kPts; ++j) {
            const int a = qMax(0, j - 1), b = qMin(kPts - 1, j + 1);
            qreal dx = xs[b] - xs[a], dy = ys[b] - ys[a];
            const qreal len = std::hypot(dx, dy);
            dx = len > 1e-6 ? dx / len : 1; dy = len > 1e-6 ? dy / len : 0;
            const qreal nx = -dy * W.thick / 2, ny = dx * W.thick / 2;    // normal offset: constant stroke width on slopes
            const qreal f = float(j) / (kPts - 1);
            const QColor c = lerp(C[i][0], C[i][1], f); const float al = float(A[i][0] + (A[i][1] - A[i][0]) * f);
            put(v[2 * j], float(xs[j] + nx), float(ys[j] + ny), c, al);
            put(v[2 * j + 1], float(xs[j] - nx), float(ys[j] - ny), c, al);
        }
        root->wave[i]->markDirty(QSGNode::DirtyGeometry);
    }

    const QColor thumb = shift(p, .06f, 1.05f);
    capsule(root->halo, xp, xp, cy, kThumbR + kHalo, thumb, thumb, .35f, .35f);
    capsule(root->core, xp, xp, cy, kThumbR, thumb, thumb, 1.f, 1.f);
    ring(root->rim, xp, cy, kThumbR, 1.2, Qt::white, .55f);
    return root;
}