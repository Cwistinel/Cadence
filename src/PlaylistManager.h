#pragma once
#include "PlaybackController.h"
#include "UndoStack.h"
#include <QVariantList>
#include <QVariantMap>

// Playlists persist in SQLite. A playlist holds each track at most once. Positions are kept dense (0..n-1).
class PlaylistManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList playlists READ playlists NOTIFY playlistsChanged)   // [{id, name, count}]
public:
    PlaylistManager(PlaybackController *pc, UndoStack *undo, QObject *parent = nullptr);
    QVariantList playlists() const { return m_lists; }

public slots:
    void reload();                                                   // also after a backup restore
    qint64 create(const QString &name);
    void rename(qint64 id, const QString &name);
    void remove(qint64 id);                                          // the UI should confirm first
    int addTracks(qint64 id, const QVariantList &trackIds);          // appends; skips tracks already present; returns number added
    QVariantList items(qint64 id) const;                             // [{itemId, trackId, pos, title, artist, album, durationMs, path, missing, virtual}]
    void removeItems(qint64 id, const QVariantList &itemIds);        // undoable
    void move(qint64 id, int from, int to);
    void play(qint64 id, int startIndex = 0);
    void enqueue(qint64 id);
    QVariantMap importM3u(const QString &url);                       // -> {ok, id, added, duplicates, missing[], unknown[], error}
    bool exists(const QString &url) const;                           // for the overwrite confirmation
    QVariantMap exportM3u(qint64 id, const QString &url, bool overwrite = false, bool relative = false);   // -> {ok, written, skipped, error}; error "exists" needs confirmation

signals:
    void playlistsChanged();
    void itemsChanged(qint64 playlistId);
    void message(const QString &text);

private:
    void restoreItems(qint64 id, const QList<QPair<int, qint64>> &gone);
    PlaybackController *m_pc;
    UndoStack *m_undo;
    QVariantList m_lists;
};