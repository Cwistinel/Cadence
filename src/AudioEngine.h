#pragma once
#include <QElapsedTimer>
#include <QMutex>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <atomic>
#include <gst/gst.h>

struct PlayItem {
    QString path;
    qint64 startMs = 0;      // offset in the physical file (CUE virtual track start)
    qint64 endMs = 0;        // 0 = play to end of file
    qint64 durationMs = 0;   // length on the engine timeline (0 = ask GStreamer)
    double gainDb = 0;       // ReplayGain, already clamped by the controller
    bool isValid() const { return !path.isEmpty(); }
    bool continuesFrom(const PlayItem &o) const { return o.endMs > 0 && path == o.path && startMs == o.endMs; }
};

// The single shared audio engine. Two playbins exist only while crossfade is in use (the second is created lazily).
class AudioEngine : public QObject {
    Q_OBJECT
public:
    enum State { Stopped, Playing, Paused };
    Q_ENUM(State)
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    State state() const { return m_state; }
    qint64 position() const;                 // ms on the item's own (virtual) timeline
    qint64 duration() const;
    double volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    double speed() const { return m_speed; }
    QStringList devices() const;
    QString device() const { return m_device; }   // empty = system default
    const PlayItem &current() const { return m_deck[m_cur].item; }

    void play(const PlayItem &item, bool autoplay = true, qint64 resumeMs = 0);
    void setNext(const PlayItem &item);      // prepared for gapless/crossfade; invalid item clears it
    void pause();
    void resume();
    void stop();
    void seek(qint64 ms);
    void setVolume(double v);                // 0..1 (perceptual cubic curve applied internally)
    void setMuted(bool m);
    void setSpeed(double s);                 // 0.5..2.0, pitch preserved via scaletempo
    void setGapless(bool on) { m_gapless = on; }
    void setCrossfade(int ms) { m_crossfadeMs = qMax(0, ms); }   // 0 = off
    void setEqualizer(bool on, const QList<double> &gainsDb);    // 10 bands, dB
    void setDevice(const QString &name);

signals:
    void stateChanged();
    void positionChanged(qint64 ms);
    void durationChanged();
    void advanced();                         // engine moved to the item that was passed to setNext()
    void finished();                         // end of queue (no next item)
    void error(const QString &path, const QString &message, bool wasCurrent);
    void devicesChanged();
    void deviceChanged();

private:
    struct BusCtx { AudioEngine *e = nullptr; int idx = 0; std::atomic<int> gen{0}; };
    struct Deck {
        GstElement *play = nullptr;
        PlayItem item;
        qint64 pendingSeek = -1, resume = 0;
        bool opening = false, wantPlay = false;
        double fade = 1.0;
        BusCtx ctx;
    };

    void ensureDeck(int i);
    void open(int i, const PlayItem &it, qint64 resume, bool play, double fade);
    void closeDeck(Deck &d);
    void applySink(Deck &d);
    void applyFilter(Deck &d);
    void applyBands(Deck &d);
    void applyVolume(int i);
    void applyRun(bool run);
    void doSeek(Deck &d, qint64 absMs);
    void setState(State s);
    void reopen();
    void onBus(int idx, GstMessage *m);
    void onDevicesChanged();
    void tick();
    void reachedEnd();
    void startCrossfade();
    void fadeStep();
    void finishFade();
    void cancelFade();
    void aboutToFinish();
    PlayItem nextCopy() const { QMutexLocker l(&m_mx); return m_next; }

    static GstBusSyncReply busSync(GstBus *, GstMessage *m, gpointer u);
    static GstBusSyncReply monSync(GstBus *, GstMessage *m, gpointer u);
    static void onAboutToFinish(GstElement *, gpointer u);

    Deck m_deck[2];
    int m_cur = 0;
    State m_state = Stopped;
    double m_volume = 0.8, m_speed = 1.0;
    bool m_muted = false, m_eqOn = false;
    QList<double> m_bands;
    QString m_device;
    GstDeviceMonitor *m_mon = nullptr;
    QTimer m_timer, m_fadeTimer;
    mutable QMutex m_mx;
    PlayItem m_next, m_advItem;
    std::atomic<bool> m_advancePending{false}, m_gapless{true};
    std::atomic<int> m_crossfadeMs{0};
    std::atomic<qint64> m_curDur{0};
    bool m_fading = false;
    int m_fadeTo = 1;
    QElapsedTimer m_fadeClock;
    mutable qint64 m_lastPos = 0;
};