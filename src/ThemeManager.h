#pragma once
#include "PlaybackController.h"
#include "Settings.h"
#include <QColor>

// Palette for the whole UI. Setting "ui/theme": light | dark | auto (default auto = background tinted by the album art).
// QML: Rectangle { color: theme.bg; Behavior on color { ColorAnimation { duration: 500 } } }
class ThemeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY themeChanged)
    Q_PROPERTY(bool dark READ dark NOTIFY themeChanged)
    Q_PROPERTY(QColor bg READ bg NOTIFY themeChanged)
    Q_PROPERTY(QColor surface READ surface NOTIFY themeChanged)
    Q_PROPERTY(QColor text READ text NOTIFY themeChanged)
    Q_PROPERTY(QColor subtext READ subtext NOTIFY themeChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged)       // art color, contrast-adjusted against bg
    Q_PROPERTY(QColor onAccent READ onAccent NOTIFY themeChanged)   // readable text/icon color on top of accent
public:
    ThemeManager(PlaybackController *pc, Settings *settings, QObject *parent = nullptr);
    QString mode() const { return m_set->value("ui/theme", QString("auto")).toString(); }
    void setMode(const QString &m) { if (m == "light" || m == "dark" || m == "auto") m_set->setValue("ui/theme", m); }
    bool dark() const { return m_p.dark; }
    QColor bg() const { return m_p.bg; }
    QColor surface() const { return m_p.surface; }
    QColor text() const { return m_p.text; }
    QColor subtext() const { return m_p.subtext; }
    QColor accent() const { return m_p.accent; }
    QColor onAccent() const { return m_p.onAccent; }
signals:
    void themeChanged();
private:
    struct Palette { QColor bg, surface, text, subtext, accent, onAccent; bool dark = true; };
    static QColor extract(qint64 trackId);      // cached on disk; runs on a worker thread
    void onTrack();
    void recompute();
    PlaybackController *m_pc;
    Settings *m_set;
    Palette m_p;
    QColor m_art;
    qint64 m_id = -1;
};