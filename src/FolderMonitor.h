#pragma once
#include "LibraryScanner.h"
#include "Settings.h"
#include <QFileSystemWatcher>
#include <QSet>
#include <QTimer>

// inotify-backed (QFileSystemWatcher) directory watching. A change in a directory triggers a scoped rescan of that directory only.
// Toggle with the setting "library/monitor" (default true).
class FolderMonitor : public QObject {
    Q_OBJECT
public:
    FolderMonitor(LibraryScanner *scanner, Settings *settings, QObject *parent = nullptr);
private:
    void rebuild();
    void watchTree(const QString &root);
    void flush();
    QFileSystemWatcher m_w;
    QSet<QString> m_dirty;
    QTimer m_debounce;
    LibraryScanner *m_s;
    Settings *m_set;
};