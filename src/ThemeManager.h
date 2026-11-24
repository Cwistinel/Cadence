#pragma once
#include "PlaybackController.h"
#include "Settings.h"
#include <QColor>

// Design tokens from the Figma file. Setting "ui/theme": light | dark | system (older "auto" = system).
// Setting "ui/artColors" (bool): derive bg/accent/tint from the playing album's artwork.
class ThemeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY themeChanged)
    Q_PROPERTY(bool dark READ dark NOTIFY themeChanged)
    Q_PROPERTY(QColor bg READ bg NOTIFY themeChanged)
    Q_PROPERTY(QColor side READ side NOTIFY themeChanged)
    Q_PROPERTY(QColor panel READ panel NOTIFY themeChanged)
    Q_PROPERTY(QColor surface READ panel NOTIFY themeChanged)       // legacy alias
    Q_PROPERTY(QColor line READ line NOTIFY themeChanged)
    Q_PROPERTY(QColor tint READ tint NOTIFY themeChanged)
    Q_PROPERTY(QColor text READ text NOTIFY themeChanged)
    Q_PROPERTY(QColor muted READ muted NOTIFY themeChanged)
    Q_PROPERTY(QColor subtext READ muted NOTIFY themeChanged)       // legacy alias
    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged)
    Q_PROPERTY(QColor onAccent READ onAccent NOTIFY themeChanged)
public:
    ThemeManager(PlaybackController *pc, Settings *settings, QObject *parent = nullptr);
    QString mode() const { return m_set->value("ui/theme", QString("system")).toString(); }
    void setMode(const QString &m) { if (m == "light" || m == "dark" || m == "system") m_set->setValue("ui/theme", m); }
    bool dark() const { return m_p.dark; }
    QColor bg() const { return m_p.bg; }
    QColor side() const { return m_p.side; }
    QColor panel() const { return m_p.panel; }
    QColor line() const { return m_p.line; }
    QColor tint() const { return m_p.tint; }
    QColor text() const { return m_p.text; }
    QColor muted() const { return m_p.muted; }
    QColor accent() const { return m_p.accent; }
    QColor onAccent() const { return m_p.onAccent; }
signals:
    void themeChanged();
private:
    struct Palette { QColor bg, side, panel, line, tint, text, muted, accent, onAccent; bool dark = true; };
    static QColor extract(qint64 trackId);      // cached on disk; runs on a worker thread
    void onTrack();
    void recompute();
    PlaybackController *m_pc;
    Settings *m_set;
    Palette m_p;
    QColor m_art;
    qint64 m_id = -1;
};