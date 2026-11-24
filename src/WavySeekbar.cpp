#include "WavySeekbar.h"
#include <QMouseEvent>
#include <QQuickWindow>
#include <QSGGeometryNode>
#include <QSGVertexColorMaterial>
#include <QtMath>
#include <algorithm>
#include <cmath>
#include <vector>

namespace {
constexpr int kCapS = 14, kCapV = 4 * (kCapS + 1);

void put(QSGGeometry::ColoredPoint2D &v, float x, float y, const QColor &c) {   // vertex colors are premultiplied
    const float a = float(c.alphaF());
    v.set(x, y, uchar(c.red() * a), uchar(c.green() * a), uchar(c.blue() * a), uchar(a * 255));
}
QSGGeometryNode *makeNode(int vertices) {
    auto *g = new QSGGeometry(QSGGeometry::defaultAttributes_ColoredPoint2D(), vertices);
    g->setDrawingMode(QSGGeometry::DrawTriangleStrip);
    auto *n = new QSGGeometryNode;
    n->setGeometry(g); n->setMaterial(new QSGVertexColorMaterial);
    n->setFlags(QSGNode::OwnsGeometry | QSGNode::OwnsMaterial);
    return n;
}
void disc(QSGGeometryNode *n, qreal cx, qreal cy, qreal r, const QColor &c) {   // circle as a triangle strip
    auto *v = n->geometry()->vertexDataAsColoredPoint2D();
    int k = 0;
    for (int i = 0; i <= kCapS; ++i) { const qreal t = M_PI_2 * i / kCapS; put(v[k++], float(cx - r * qCos(t)), float(cy - r * qSin(t)), c); put(v[k++], float(cx - r * qCos(t)), float(cy + r * qSin(t)), c); }
    for (int i = kCapS; i >= 0; --i) { const qreal t = M_PI_2 * i / kCapS; put(v[k++], float(cx + r * qCos(t)), float(cy - r * qSin(t)), c); put(v[k++], float(cx + r * qCos(t)), float(cy + r * qSin(t)), c); }
    n->markDirty(QSGNode::DirtyGeometry);
}
struct Root : QSGNode {
    QSGGeometryNode *wave, *thumb;
    Root() { wave = make(2); thumb = make(kCapV); }
    QSGGeometryNode *make(int n) { auto *g = makeNode(n); appendChildNode(g); return g; }
};
}  // namespace

WavySeekbar::WavySeekbar(QQuickItem *parent) : QQuickItem(parent) {
    setFlag(ItemHasContents);
    setAcceptedMouseButtons(Qt::LeftButton);
    m_stamp.start(); m_frame.start();
    m_tick.setInterval(33);
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
void WavySeekbar::setThumbColor(const QColor &c) { if (c == m_thumb) return; m_thumb = c; emit thumbColorChanged(); update(); }
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
    m_dragMs = qBound<qreal>(0, x / qMax<qreal>(1, width()), 1) * m_dur;
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
    if (m_tick.isActive() && !m_drag) m_phase = std::fmod(m_phase + dt / 2.6, 1.0);   // one wavelength every 2.6 s

    const qreal s = qMax<qreal>(0.5, height() / 20.0);                // the Figma bar is 20 high; the larger one is the same shape, scaled
    const qreal amp = 4.5 * s, lambda = 36 * s, stroke = 2 * s, thumbR = 5 * s, cy = height() / 2 - 0.5 * s, ty = height() / 2 - s;
    const qreal W = qMax<qreal>(1, width());
    qreal cur = m_drag ? m_dragMs : m_pos + (m_playing ? m_stamp.elapsed() : 0);
    if (m_dur > 0) cur = qBound<qreal>(0, cur, m_dur);
    const qreal xp = (m_dur > 0 ? cur / m_dur : 0) * W;

    std::vector<float> xs;                                            // sample every 2 px, plus an exact sample at the thumb
    xs.reserve(size_t(W / 2) + 4);
    for (float x = 0; x < W; x += 2) xs.push_back(x);
    xs.push_back(float(W));
    if (xp > 0 && xp < W) xs.insert(std::upper_bound(xs.begin(), xs.end(), float(xp)), float(xp));
    const int n = int(xs.size());

    QSGGeometry *g = root->wave->geometry();
    if (g->vertexCount() != 2 * n) g->allocate(2 * n);
    auto *v = g->vertexDataAsColoredPoint2D();
    std::vector<float> ys(n);
    const qreal shift = m_phase * lambda;
    for (int i = 0; i < n; ++i) ys[i] = float(cy + amp * qSin(2 * M_PI * (xs[i] - shift) / lambda));
    for (int i = 0; i < n; ++i) {
        const int a = qMax(0, i - 1), b = qMin(n - 1, i + 1);
        qreal dx = xs[b] - xs[a], dy = ys[b] - ys[a];
        const qreal len = std::hypot(dx, dy);
        dx = len > 1e-6 ? dx / len : 1; dy = len > 1e-6 ? dy / len : 0;
        const float nx = float(-dy * stroke / 2), ny = float(dx * stroke / 2);   // normal offset: constant stroke width on slopes
        const QColor &c = xs[i] <= xp + 0.01 ? m_accent : m_track;
        put(v[2 * i], xs[i] + nx, ys[i] + ny, c);
        put(v[2 * i + 1], xs[i] - nx, ys[i] - ny, c);
    }
    root->wave->markDirty(QSGNode::DirtyGeometry);
    disc(root->thumb, xp, ty, thumbR, m_thumb);
    return root;
}