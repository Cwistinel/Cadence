#pragma once
#include <QObject>
#include <QStringList>
#include <QThreadPool>
#include <QVariantList>
#include <atomic>

// Library manager: folder list, one background scan job at a time, drag-and-drop import, duplicates, history reset.
// Files are never touched: rows are only added, updated or flagged missing.
class LibraryScanner : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList folders READ folders NOTIFY foldersChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(int total READ total NOTIFY progressChanged)
public:
    explicit LibraryScanner(QObject *parent = nullptr);
    ~LibraryScanner() override;
    QStringList folders() const { return m_folders; }
    bool scanning() const { return m_running; }
    int progress() const { return m_progress; }
    int total() const { return m_total; }

public slots:
    void addFolder(const QString &path);              // path or file: URL
    void removeFolder(const QString &path);           // tracks are hidden (missing), user data is kept
    void rescanAll();
    void rescan(const QString &path);                 // a library folder, or any directory inside one (incremental)
    void importPaths(const QVariantList &urls);       // dropped files (-> imported(ids)), .cue files, folders (-> addFolder)
    void cancel();
    QVariantList duplicates();                        // [{reason, tracks:[{id,title,artist,album,path,durationMs,size}]}]
    void clearHistory();
    void reloadFolders() { loadFolders(); emit foldersChanged(); }   // after a restore replaced the folders table

signals:
    void foldersChanged();
    void scanningChanged();
    void progressChanged();
    void libraryChanged();                            // rows were added/changed/hidden
    void scanFinished(const QString &path);           // folder or directory scanned (empty for file imports)
    void imported(const QVariantList &ids);           // track ids of the files from importPaths()
    void message(const QString &text);

private:
    struct Job { QString scope; QStringList files; bool loose = false; };
    void enqueue(const Job &j);
    void next();
    void loadFolders();
    void runJob(Job j);
    void scan(const Job &j, QVariantList &ids, QString &msg);
    void done(const Job &j, const QVariantList &ids, const QString &msg);

    QThreadPool m_pool;                               // one thread: scans never run concurrently
    QList<Job> m_jobs;
    Job m_run;
    QStringList m_folders;
    std::atomic<bool> m_cancel{false};
    bool m_running = false;
    int m_progress = 0, m_total = 0;
};