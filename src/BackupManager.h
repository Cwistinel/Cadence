#pragma once
#include "LibraryScanner.h"
#include "PlaybackController.h"
#include "Settings.h"
#include "UndoStack.h"
#include <QVariantMap>

// A backup is one `.cadbak` file (a SQLite copy) holding library rows (incl. CUE virtual tracks), favorites, history, metadata overrides,
// lyrics edits, playlists, queue state and preferences. Music files are never included. Connect restored() to
// PlaylistManager::reload and LyricsManager::reload in main.cpp.
class BackupManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString backupDir READ backupDir CONSTANT)   // ~/.local/share/cadence/backups
public:
    BackupManager(PlaybackController *pc, LibraryScanner *lib, Settings *set, UndoStack *undo, QObject *parent = nullptr)
        : QObject(parent), m_pc(pc), m_lib(lib), m_set(set), m_undo(undo) {}
    QString backupDir() const;

public slots:
    QVariantMap create(const QString &urlOrPath, bool overwrite = false);   // {ok, path} | {ok:false, error}; error "exists" => ask, then retry with overwrite
    QVariantMap inspect(const QString &urlOrPath) const;                    // validates without changing anything: {ok, created, tracks, playlists} | {ok:false, error}
    QVariantMap restore(const QString &urlOrPath);                          // the UI must confirm first; makes a safety copy; {ok, safetyCopy} | {ok:false, error}
    bool exists(const QString &urlOrPath) const;
    void autoBackup();                                                      // at most one per day, newest 5 kept
    QString checkIntegrity() const;                                         // "ok" or a description
    QString recover();                                                      // keeps a copy of the damaged file, tries REINDEX; "ok" or advice

signals:
    void restored();

private:
    void syncMissing();
    PlaybackController *m_pc;
    LibraryScanner *m_lib;
    Settings *m_set;
    UndoStack *m_undo;
};