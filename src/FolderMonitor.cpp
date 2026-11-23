#include "FolderMonitor.h"
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <algorithm>

FolderMonitor::FolderMonitor(LibraryScanner *s, Settings *set, QObject *p) : QObject(p), m_s(s), m_set(set) {
    m_debounce.setSingleShot(true);
    connect(&m_w, &QFileSystemWatcher::directoryChanged, this, [this](const QString &d) { m_dirty << d; m_debounce.start(1500); });
    connect(&m_debounce, &QTimer::timeout, this, &FolderMonitor::flush);
    connect(s, &LibraryScanner::foldersChanged, this, &FolderMonitor::rebuild);
    connect(set, &Settings::changed, this, [this](const QString &k) { if (k == "library/monitor") rebuild(); });
    rebuild();
}

void FolderMonitor::rebuild() {
    if (!m_w.directories().isEmpty()) m_w.removePaths(m_w.directories());
    m_dirty.clear();
    if (!m_set->value("library/monitor", true).toBool()) return;
    for (const QString &f : m_s->folders()) watchTree(f);
}

void FolderMonitor::watchTree(const QString &root) {
    QStringList l{root};
    QDirIterator it(root, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) l << it.next();
    m_w.addPaths(l);
}

void FolderMonitor::flush() {
    QStringList dirs = m_dirty.values();
    m_dirty.clear();
    std::sort(dirs.begin(), dirs.end());                       // parents sort before their children
    QString last;
    for (QString d : dirs) {
        if (!last.isEmpty() && d.startsWith(last + '/')) continue;   // already covered by a changed parent
        last = d;
        while (d.size() > 1 && !QFileInfo(d).isDir()) d = QFileInfo(d).absolutePath();   // deleted: rescan from the nearest existing parent
        watchTree(d);                                          // pick up new subdirectories
        m_s->rescan(d);
    }
}