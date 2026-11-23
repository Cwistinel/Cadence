#include "Mpris.h"
#include "ArtworkManager.h"
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QUrl>

namespace {
const QString kService = QStringLiteral("org.mpris.MediaPlayer2.cadence");
const QString kPath = QStringLiteral("/org/mpris/MediaPlayer2");
}  // namespace

QString MprisPlayer::playbackStatus() const {
    switch (m_m->pc()->state()) { case 1: return QStringLiteral("Playing"); case 2: return QStringLiteral("Paused"); default: return QStringLiteral("Stopped"); }
}

QString MprisPlayer::loopStatus() const {
    switch (m_m->pc()->repeat()) { case 1: return QStringLiteral("Playlist"); case 2: return QStringLiteral("Track"); default: return QStringLiteral("None"); }
}

void MprisPlayer::setLoopStatus(const QString &s) { m_m->pc()->setRepeat(s == "Track" ? 2 : s == "Playlist" ? 1 : 0); }

void MprisPlayer::SetPosition(const QDBusObjectPath &track, qlonglong posUs) {
    if (track.path().endsWith('/' + QString::number(m_m->pc()->currentTrack().id))) m_m->pc()->seek(posUs / 1000);   // stale track ids are ignored per spec
}

Mpris::Mpris(PlaybackController *pc, QObject *parent) : QObject(parent), m_pc(pc) {
    new MprisRoot(this);
    m_player = new MprisPlayer(this);
    QDBusConnection bus = QDBusConnection::sessionBus();
    m_registered = bus.registerService(kService) && bus.registerObject(kPath, this, QDBusConnection::ExportAdaptors);
    if (!m_registered) qWarning("MPRIS registration failed (no session bus, or the name is taken)");
    m_defer.setSingleShot(true); m_defer.setInterval(30);
    connect(&m_defer, &QTimer::timeout, this, &Mpris::refresh);
    for (auto sig : {&PlaybackController::stateChanged, &PlaybackController::trackChanged, &PlaybackController::modeChanged, &PlaybackController::volumeChanged,
                     &PlaybackController::navChanged, &PlaybackController::speedChanged, &PlaybackController::durationChanged})
        connect(pc, sig, &m_defer, qOverload<>(&QTimer::start));
    connect(pc, &PlaybackController::seeked, this, [this](qint64 ms) { if (m_registered) emit m_player->Seeked(ms * 1000); });
    m_last = properties();
}

Mpris::~Mpris() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (m_registered) { bus.unregisterObject(kPath); bus.unregisterService(kService); }   // released on shutdown
}

bool Mpris::raiseExisting() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected() || !bus.interface()->isServiceRegistered(kService).value()) return false;
    QDBusInterface(kService, kPath, "org.mpris.MediaPlayer2", bus).call("Raise");
    return true;
}

QVariantMap Mpris::metadata() const {
    QVariantMap m;
    if (!m_pc->hasTrack()) { m["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/mpris/MediaPlayer2/TrackList/NoTrack"))); return m; }
    const Track &t = m_pc->currentTrack();
    if (t.id != m_artId) {   // cached per track: artwork lookup touches the DB
        m_artId = t.id; m_artUrl.clear();
        if (!ArtworkManager::image(t.id).isNull()) m_artUrl = QUrl::fromLocalFile(ArtworkManager::cacheDir() + '/' + ArtworkManager::key(t.id) + ".jpg").toString();
    }
    m["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath(QStringLiteral("/org/mpris/MediaPlayer2/Track/%1").arg(t.id)));
    m["mpris:length"] = qlonglong(m_pc->duration()) * 1000;
    m["xesam:title"] = m_pc->trackMap().value("title").toString();
    m["xesam:album"] = t.album;
    m["xesam:artist"] = t.artist.isEmpty() ? QStringList() : QStringList{t.artist};
    if (!m_artUrl.isEmpty()) m["mpris:artUrl"] = m_artUrl;
    return m;
}

QVariantMap Mpris::properties() const {
    return {{"PlaybackStatus", m_player ? m_player->playbackStatus() : QString()}, {"LoopStatus", m_player ? m_player->loopStatus() : QString()},
            {"Rate", m_pc->speed()}, {"Shuffle", m_pc->shuffle()}, {"Metadata", metadata()}, {"Volume", m_pc->volume()},
            {"CanGoNext", m_pc->canNext()}, {"CanGoPrevious", m_pc->canPrevious()}, {"CanPlay", m_pc->queue()->count() > 0},
            {"CanPause", m_pc->hasTrack()}, {"CanSeek", m_pc->hasTrack()}};
}

void Mpris::refresh() {   // only properties that actually changed go on the bus
    const QVariantMap now = properties();
    QVariantMap diff;
    for (auto it = now.cbegin(); it != now.cend(); ++it) if (m_last.value(it.key()) != it.value()) diff.insert(it.key(), it.value());
    m_last = now;
    if (diff.isEmpty() || !m_registered) return;
    QDBusMessage s = QDBusMessage::createSignal(kPath, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"));
    s << QStringLiteral("org.mpris.MediaPlayer2.Player") << diff << QStringList();
    QDBusConnection::sessionBus().send(s);
}