#pragma once
#include <QColor>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QTimer>

// Port of LastWave's WavyProgressTrack: three thin gradient waves over the played bar, flat while scrubbing.
// Frames are requested (~30 fps) only while playing and visible.
class WavySeekbar : public QQuickItem {
    Q_OBJECT
    Q_PROPERTY(qreal position READ position WRITE setPosition NOTIFY positionChanged)      // ms
    Q_PROPERTY(qreal duration READ duration WRITE setDuration NOTIFY durationChanged)      // ms
    Q_PROPERTY(bool playing READ playing WRITE setPlaying NOTIFY playingChanged)
    Q_PROPERTY(QColor accent READ accent WRITE setAccent NOTIFY accentChanged)
    Q_PROPERTY(QColor trackColor READ trackColor WRITE setTrackColor NOTIFY trackColorChanged)   // unplayed part
    Q_PROPERTY(bool scrubbing READ scrubbing NOTIFY scrubbingChanged)
    Q_PROPERTY(qreal scrubPosition READ scrubPosition NOTIFY scrubPositionChanged)
public:
    explicit WavySeekbar(QQuickItem *parent = nullptr);
    qreal position() const { return m_pos; }
    qreal duration() const { return m_dur; }
    bool playing() const { return m_playing; }
    QColor accent() const { return m_accent; }
    QColor trackColor() const { return m_track; }
    bool scrubbing() const { return m_drag; }
    qreal scrubPosition() const { return m_dragMs; }
    void setPosition(qreal v);
    void setDuration(qreal v);
    void setPlaying(bool v);
    void setAccent(const QColor &c);
    void setTrackColor(const QColor &c);

signals:
    void positionChanged();
    void durationChanged();
    void playingChanged();
    void accentChanged();
    void trackColorChanged();
    void scrubbingChanged();
    void scrubPositionChanged();
    void seekRequested(qreal ms);

protected:
    QSGNode *updatePaintNode(QSGNode *old, UpdatePaintNodeData *) override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void itemChange(ItemChange c, const ItemChangeData &d) override;

private:
    void dragTo(qreal x);
    void syncTimer();
    qreal m_pos = 0, m_dur = 0, m_dragMs = 0, m_clock = 0, m_flat = 0;
    bool m_playing = false, m_drag = false;
    QColor m_accent{0xE8, 0xA8, 0x4C}, m_track{255, 255, 255, 56};
    QElapsedTimer m_stamp, m_frame;
    QTimer m_tick;
};