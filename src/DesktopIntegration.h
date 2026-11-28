#pragma once
#include "PlaybackController.h"
#include "Settings.h"
#include <QDBusInterface>
#include <QMenu>
#include <QSystemTrayIcon>
#include <QTimer>

// System tray + track-change notifications. Every action is forwarded to the PlaybackController.
// Settings: ui/closeToTray (default false), ui/notifications (default true).
class DesktopIntegration : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool trayAvailable READ trayAvailable CONSTANT)
public:
    DesktopIntegration(PlaybackController *pc, Settings *settings, QObject *parent = nullptr);
    bool trayAvailable() const { return m_tray != nullptr; }
    Q_INVOKABLE bool closeToTray() const { return m_tray && m_tray->isVisible() && m_set->flag("ui/closeToTray", false); }
public slots:
    void quit();
signals:
    void showRequested();
    void toggleRequested();
private slots:
    void onAction(uint id, const QString &key);
private:
    void onTrack();
    void notify();
    PlaybackController *m_pc;
    Settings *m_set;
    QSystemTrayIcon *m_tray = nullptr;
    QMenu m_menu;
    QAction *m_play = nullptr;
    QDBusInterface m_n;
    QTimer m_timer;
    uint m_nid = 0;
    qint64 m_lastId = 0;
    bool m_actions = false;
};