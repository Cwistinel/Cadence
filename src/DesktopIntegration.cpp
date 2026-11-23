#include "DesktopIntegration.h"
#include "ArtworkManager.h"
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusReply>
#include <QGuiApplication>
#include <QIcon>

DesktopIntegration::DesktopIntegration(PlaybackController *pc, Settings *s, QObject *p)
    : QObject(p), m_pc(pc), m_set(s), m_n("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications") {
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        m_tray = new QSystemTrayIcon(QIcon::fromTheme("cadence", QIcon(":/assets/cadence.svg")), this);
        m_menu.addAction(tr("Show / Hide"), this, &DesktopIntegration::toggleRequested);
        m_play = m_menu.addAction(tr("Play"), pc, &PlaybackController::togglePlayPause);
        m_menu.addAction(tr("Previous"), pc, &PlaybackController::previous);
        m_menu.addAction(tr("Next"), pc, &PlaybackController::next);
        m_menu.addSeparator();
        m_menu.addAction(tr("Exit"), this, &DesktopIntegration::quit);
        m_tray->setContextMenu(&m_menu);
        m_tray->setToolTip("Cadence");
        connect(m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason r) { if (r == QSystemTrayIcon::Trigger) emit toggleRequested(); });
        connect(pc, &PlaybackController::stateChanged, this, [this] { m_play->setText(m_pc->playing() ? tr("Pause") : tr("Play")); });
        m_tray->show();
    }
    if (m_n.isValid()) {
        const QDBusReply<QStringList> caps = m_n.call("GetCapabilities");
        m_actions = caps.isValid() && caps.value().contains("actions");
        QDBusConnection::sessionBus().connect("org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications",
                                              "ActionInvoked", this, SLOT(onAction(uint, QString)));
    }
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, &DesktopIntegration::notify);
    connect(pc, &PlaybackController::trackChanged, this, &DesktopIntegration::onTrack);
    m_lastId = pc->currentTrack().id;   // the restored track is not "new"
}

void DesktopIntegration::quit() { QCoreApplication::quit(); }

void DesktopIntegration::onTrack() {   // trackChanged also fires for favorite/metadata edits: only a different track counts
    const qint64 id = m_pc->currentTrack().id;
    if (id == m_lastId) return;
    m_lastId = id;
    if (id) m_timer.start(250);        // engine state settles first
}

void DesktopIntegration::notify() {
    const Track &t = m_pc->currentTrack();
    if (!t.id || !m_pc->playing() || !m_n.isValid() || !m_set->flag("ui/notifications", true) || QGuiApplication::applicationState() == Qt::ApplicationActive) return;
    QVariantMap hints{{"desktop-entry", "cadence"}};
    if (!ArtworkManager::image(t.id).isNull()) hints["image-path"] = ArtworkManager::cacheDir() + '/' + ArtworkManager::key(t.id) + ".jpg";
    const QStringList actions = m_actions ? QStringList{"prev", tr("Previous"), "playpause", tr("Play/Pause"), "next", tr("Next")} : QStringList();
    const QString title = m_pc->trackMap().value("title").toString();
    const QString body = t.artist.isEmpty() ? t.album : (t.album.isEmpty() ? t.artist : t.artist + QStringLiteral(" — ") + t.album);
    const QDBusReply<uint> r = m_n.call("Notify", QStringLiteral("Cadence"), m_nid, QStringLiteral("cadence"), title, body, actions, hints, 4000);
    if (r.isValid()) m_nid = r.value();
}

void DesktopIntegration::onAction(uint id, const QString &key) {
    if (id != m_nid) return;
    if (key == "prev") m_pc->previous(); else if (key == "next") m_pc->next(); else if (key == "playpause") m_pc->togglePlayPause();
}