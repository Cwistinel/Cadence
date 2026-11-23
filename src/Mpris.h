#pragma once
#include "PlaybackController.h"
#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QTimer>

class MprisPlayer;

// Exports org.mpris.MediaPlayer2 and org.mpris.MediaPlayer2.Player at /org/mpris/MediaPlayer2. Every call goes to the PlaybackController.
class Mpris : public QObject {
    Q_OBJECT
public:
    explicit Mpris(PlaybackController *pc, QObject *parent = nullptr);
    ~Mpris() override;
    static bool raiseExisting();                  // another instance owns the bus name: ask it to show itself
    PlaybackController *pc() const { return m_pc; }
    QVariantMap metadata() const;
    QVariantMap properties() const;               // every Player property (except Position), keyed by D-Bus name
signals:
    void raiseRequested();
    void quitRequested();
private:
    void refresh();
    PlaybackController *m_pc;
    MprisPlayer *m_player = nullptr;
    QVariantMap m_last;
    QTimer m_defer;
    bool m_registered = false;
    mutable qint64 m_artId = -1;
    mutable QString m_artUrl;
};

class MprisRoot : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ yes)
    Q_PROPERTY(bool CanRaise READ yes)
    Q_PROPERTY(bool HasTrackList READ no)
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(QStringList SupportedUriSchemes READ schemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ mimes)
public:
    explicit MprisRoot(Mpris *m) : QDBusAbstractAdaptor(m), m_m(m) {}
    bool yes() const { return true; }
    bool no() const { return false; }
    QString identity() const { return QStringLiteral("Cadence"); }
    QString desktopEntry() const { return QStringLiteral("cadence"); }
    QStringList schemes() const { return {}; }
    QStringList mimes() const { return {"audio/mpeg", "audio/aac", "audio/flac", "audio/ogg", "audio/opus", "audio/x-wav", "audio/amr", "audio/amr-wb"}; }
public slots:
    void Raise() { emit m_m->raiseRequested(); }
    void Quit() { emit m_m->quitRequested(); }
private:
    Mpris *m_m;
};

class MprisPlayer : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QString LoopStatus READ loopStatus WRITE setLoopStatus)
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(bool Shuffle READ shuffle WRITE setShuffle)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double MinimumRate READ minRate)
    Q_PROPERTY(double MaximumRate READ maxRate)
    Q_PROPERTY(bool CanGoNext READ canNext)
    Q_PROPERTY(bool CanGoPrevious READ canPrevious)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)
public:
    explicit MprisPlayer(Mpris *m) : QDBusAbstractAdaptor(m), m_m(m) {}
    QString playbackStatus() const;
    QString loopStatus() const;
    void setLoopStatus(const QString &s);
    double rate() const { return m_m->pc()->speed(); }
    void setRate(double r) { m_m->pc()->setSpeed(r); }
    bool shuffle() const { return m_m->pc()->shuffle(); }
    void setShuffle(bool b) { m_m->pc()->setShuffle(b); }
    QVariantMap metadata() const { return m_m->metadata(); }
    double volume() const { return m_m->pc()->volume(); }
    void setVolume(double v) { m_m->pc()->setVolume(v); }
    qlonglong position() const { return qlonglong(m_m->pc()->position()) * 1000; }
    double minRate() const { return 0.5; }
    double maxRate() const { return 2.0; }
    bool canNext() const { return m_m->pc()->canNext(); }
    bool canPrevious() const { return m_m->pc()->canPrevious(); }
    bool canPlay() const { return m_m->pc()->queue()->count() > 0; }
    bool canPause() const { return m_m->pc()->hasTrack(); }
    bool canSeek() const { return m_m->pc()->hasTrack(); }
    bool canControl() const { return true; }
public slots:
    void Next() { m_m->pc()->next(); }
    void Previous() { m_m->pc()->previous(); }
    void Pause() { m_m->pc()->pause(); }
    void PlayPause() { m_m->pc()->togglePlayPause(); }
    void Stop() { m_m->pc()->stop(); }
    void Play() { m_m->pc()->play(); }
    void Seek(qlonglong offsetUs) { m_m->pc()->seekBy(offsetUs / 1000); }
    void SetPosition(const QDBusObjectPath &track, qlonglong posUs);
signals:
    void Seeked(qlonglong Position);
private:
    Mpris *m_m;
};