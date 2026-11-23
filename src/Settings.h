#pragma once
#include <QDir>
#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QVariant>

// Config lives in ~/.config/cadence/cadence.conf. In QML, bind reactively with:  (settings.revision, settings.value("key", def))
class Settings : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
public:
    explicit Settings(QObject *p = nullptr) : QObject(p), m_s(file(), QSettings::IniFormat) {}
    int revision() const { return m_rev; }
    Q_INVOKABLE QVariant value(const QString &k, const QVariant &d = {}) const { return m_s.value(k, d); }
    Q_INVOKABLE bool flag(const QString &k, bool d = false) const { return m_s.value(k, d).toBool(); }
    Q_INVOKABLE double number(const QString &k, double d = 0) const { return m_s.value(k, d).toDouble(); }
    Q_INVOKABLE QString text(const QString &k, const QString &d = {}) const { return m_s.value(k, d).toString(); }
    Q_INVOKABLE void setValue(const QString &k, const QVariant &v) {
        if (m_s.contains(k) && m_s.value(k) == v) return;
        m_s.setValue(k, v); m_s.sync(); ++m_rev; emit changed(k); emit revisionChanged();
    }
    QVariantMap all() const { QVariantMap m; for (const QString &k : m_s.allKeys()) m.insert(k, m_s.value(k)); return m; }
    void replaceAll(const QVariantMap &m) {
        m_s.clear(); for (auto it = m.begin(); it != m.end(); ++it) m_s.setValue(it.key(), it.value());
        m_s.sync(); ++m_rev; emit revisionChanged();
    }
signals:
    void changed(const QString &key);
    void revisionChanged();
private:
    static QString file() { const QString d = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation); QDir().mkpath(d); return d + "/cadence.conf"; }
    QSettings m_s;
    int m_rev = 0;
};