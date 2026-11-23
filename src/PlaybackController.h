#pragma once
#include "AudioEngine.h"
#include "QueueModel.h"
#include "Settings.h"
#include "UndoStack.h"
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

// The one entry point for playback. QML, MPRIS, media keys, tray, notifications and the mini-player all call this class,
// and it is the only thing that talks to the AudioEngine.
class PlaybackController : public QObject {
    Q_OBJECT
    Q_PROPERTY(int state READ state NOTIFY stateChanged)                       // 0 stopped, 1 playing, 2 paused
    Q_PROPERTY(bool playing READ playing NOTIFY stateChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)           // ms on the (virtual) track timeline
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted WRITE setMuted NOTIFY volumeChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(bool shuffle READ shuffle WRITE setShuffle NOTIFY modeChanged)
    Q_PROPERTY(int repeat READ repeat WRITE setRepeat NOTIFY modeChanged)     // 0 off, 1 all, 2 one
    Q_PROPERTY(bool hasTrack READ hasTrack NOTIFY trackChanged)
    Q_PROPERTY(QVariantMap track READ trackMap NOTIFY trackChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY trackChanged)
    Q_PROPERTY(bool canNext READ canNext NOTIFY navChanged)
    Q_PROPERTY(bool canPrevious READ canPrevious NOTIFY navChanged)
    Q_PROPERTY(QueueModel *queue READ queue CONSTANT)
    Q_PROPERTY(QStringList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QString device READ device NOTIFY deviceChanged)
public:
    enum Repeat { Off, All, One };
    Q_ENUM(Repeat)
    PlaybackController(AudioEngine *engine, Settings *settings, UndoStack *undo, QObject *parent = nullptr);

    int state() const { return int(m_engine->state()); }
    bool playing() const { return m_engine->state() == AudioEngine::Playing; }
    qint64 position() const { return m_pos; }
    qint64 duration() const;
    double volume() const { return m_engine->volume(); }
    bool muted() const { return m_engine->muted(); }
    double speed() const { return m_engine->speed(); }
    bool shuffle() const { return m_shuffle; }
    int repeat() const { return m_repeat; }
    bool hasTrack() const { return m_cur >= 0; }
    int currentIndex() const { return m_cur; }
    bool canNext() const;
    bool canPrevious() const { return m_cur >= 0; }
    QVariantMap trackMap() const;
    const Track &currentTrack() const;            // an empty Track (id 0) when there is none
    QueueModel *queue() { return &m_q; }
    QStringList devices() const { return m_engine->devices(); }
    QString device() const { return m_engine->device(); }
    void setVolume(double v);
    void setMuted(bool m);
    void setSpeed(double s);
    void setShuffle(bool on);
    void setRepeat(int r);

public slots:
    void play();                                  // resumes, or starts the current track (also after a restart)
    void pause();
    void togglePlayPause();
    void stop();
    void next();
    void previous();                              // restarts the track when more than 3 s in
    void seek(qint64 ms);
    void seekBy(qint64 deltaMs);
    void volumeBy(double delta);
    void playIndex(int queueIndex);
    void playTracks(const QVariantList &ids, int startIndex = 0);   // replaces the queue
    void playFolder(const QString &path);                           // replaces the queue with a folder (recursive)
    void enqueue(const QVariantList &ids, bool afterCurrent = false);
    void enqueueFolder(const QString &path, bool afterCurrent = false);
    void removeAt(int queueIndex);                                  // undoable
    void moveTrack(int from, int to);                               // undoable
    void clearQueue();
    void toggleFavorite();
    void setFavorite(qint64 id, bool on);                           // undoable
    void refreshTrack(qint64 id);                                   // call after metadata/lyrics edits
    void setDevice(const QString &name);
    void shutdown();
    void reloadFromDatabase();
    void saveNow();                                                // flush state; call from aboutToQuit

signals:
    void stateChanged();
    void positionChanged(qint64 ms);
    void durationChanged();
    void volumeChanged();
    void speedChanged();
    void modeChanged();
    void trackChanged();
    void navChanged();
    void devicesChanged();
    void deviceChanged();
    void seeked(qint64 ms);                       // explicit jumps only (for MPRIS Seeked)
    void trackUpdated(qint64 id);                 // a row changed (favorite, plays, metadata)
    void message(const QString &text);            // short user-facing notices (toasts)

private:
    PlayItem toItem(const Track &t) const;
    double gain(const Track &t) const;
    void startIndex(int i, bool autoplay = true, qint64 resume = 0);
    void setCurrent(int i);
    void armNext();
    int peekNext(bool manual);
    void resetOrder();
    void applyMap(const std::function<int(int)> &f);
    void insertRaw(int at, const QList<Track> &ts);
    void removeRaw(int i);
    void moveRaw(int from, int to);
    void add(const QList<Track> &ts, bool afterCurrent);
    void replaceQueue(const QList<Track> &ts, qint64 startId);
    QList<qint64> idsInFolder(const QString &path) const;
    void writeFavorite(qint64 id, bool on);
    void recordPlay(qint64 id);
    void restartCurrent();
    void applyEq();
    void applyAll();
    void restore();
    void scheduleSave() { m_saveTimer.start(); }
    void flush();
    void savePosition();
    void onSetting(const QString &key);
    void onState();
    void onPosition(qint64 ms);
    void onAdvanced();
    void onFinished();
    void onError(const QString &path, const QString &msg, bool wasCurrent);
    void onDevice();

    AudioEngine *m_engine;
    Settings *m_set;
    UndoStack *m_undo;
    QueueModel m_q;
    QList<int> m_order;                 // playback order as queue indices (identity unless shuffled)
    int m_op = -1;                      // position of the current track inside m_order
    int m_cur = -1, m_pending = -1, m_badNext = -1, m_failures = 0, m_repeat = Off;
    bool m_shuffle = false, m_counted = false;
    qint64 m_pos = 0;
    QTimer m_saveTimer, m_posTimer;
};