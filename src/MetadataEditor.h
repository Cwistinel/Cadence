#pragma once
#include "LibraryScanner.h"
#include "PlaybackController.h"
#include "UndoStack.h"

// Edits are stored as overrides in SQLite; audio files are never written. Only fields that differ from the original are stored.
// Field keys: title, artist, album, albumArtist, genre, trackNo.
class MetadataEditor : public QObject {
    Q_OBJECT
public:
    MetadataEditor(PlaybackController *pc, LibraryScanner *lib, UndoStack *undo, QObject *parent = nullptr) : QObject(parent), m_pc(pc), m_lib(lib), m_undo(undo) {}
    Q_INVOKABLE QVariantMap get(qint64 id) const;                   // {original:{...}, current:{...}, overridden:bool}
    Q_INVOKABLE void save(qint64 id, const QVariantMap &fields);    // undoable; "cancel" = simply don't call this
    Q_INVOKABLE void reset(qint64 id);                              // drop all overrides for the track; undoable
private:
    void apply(qint64 id, const QVariantList &values);              // 6 values in key order; all-null removes the override row
    PlaybackController *m_pc;
    LibraryScanner *m_lib;
    UndoStack *m_undo;
};