#pragma once
#include <QList>
#include <QObject>
#include <QPair>
#include <QString>
#include <functional>

// Minimal undo: each entry is a closure that reverses one app-level action. Undo closures must not push new entries.
class UndoStack : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)
    Q_PROPERTY(QString label READ label NOTIFY changed)
public:
    using QObject::QObject;
    bool canUndo() const { return !m_s.isEmpty(); }
    QString label() const { return m_s.isEmpty() ? QString() : m_s.last().first; }
    void push(const QString &label, std::function<void()> undo) { m_s.append({label, std::move(undo)}); if (m_s.size() > 50) m_s.removeFirst(); emit changed(); }
    Q_INVOKABLE void undo() { if (m_s.isEmpty()) return; const auto e = m_s.takeLast(); emit changed(); e.second(); }
    Q_INVOKABLE void clear() { m_s.clear(); emit changed(); }
signals:
    void changed();
private:
    QList<QPair<QString, std::function<void()>>> m_s;
};