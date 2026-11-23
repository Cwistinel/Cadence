#pragma once
#include "PlaybackController.h"
#include "UndoStack.h"
#include <QStringList>
#include <QVariantList>

struct LyricLine { qint64 ms = -1; QString text; };            // ms = -1: unsynchronized line
struct LyricsDoc { QList<LyricLine> lines; QStringList meta; bool synced = false; };

// Lyrics of the current track. Customization (font family/size/weight/alignment) lives in Settings under
// lyrics/fontFamily, lyrics/fontSize, lyrics/fontWeight, lyrics/align and is applied by the QML view.
class LyricsManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY lyricsChanged)
    Q_PROPERTY(bool synced READ synced NOTIFY lyricsChanged)
    Q_PROPERTY(QVariantList lines READ lines NOTIFY lyricsChanged)      // [{ms, text}]
    Q_PROPERTY(QString source READ source NOTIFY lyricsChanged)         // edited | file | embedded | none
    Q_PROPERTY(QString rawText READ rawText NOTIFY lyricsChanged)       // what the editor should start with
    Q_PROPERTY(int currentLine READ currentLine NOTIFY currentLineChanged)
public:
    LyricsManager(PlaybackController *pc, UndoStack *undo, QObject *parent = nullptr);
    static LyricsDoc parse(const QString &text);
    static QString format(const LyricsDoc &doc);
    bool hasLyrics() const { return !m_doc.lines.isEmpty(); }
    bool synced() const { return m_doc.synced; }
    QVariantList lines() const { return m_lines; }
    QString source() const { return m_source; }
    QString rawText() const { return m_raw; }
    int currentLine() const { return m_line; }

public slots:
    void reload();                                         // also after a backup restore
    void save(const QString &text);                        // stores an edited copy for the current track (undoable). Empty text = remove the edit
    void removeEdit() { save(QString()); }
    QString readFile(const QString &urlOrPath) const;      // import: returns text for the editor; nothing is stored until save()
    QString shift(const QString &text, qint64 deltaMs) const;   // preview helper: all timestamps + delta (clamped at 0)
    QVariantList parseText(const QString &text) const;     // [{ms, text}] for per-line editing
    QString compose(const QVariantList &lines) const;      // inverse of parseText (header tags are not kept)

signals:
    void lyricsChanged();
    void currentLineChanged();

private:
    QString findFile(const Track &t) const;
    void store(qint64 id, const QVariant &content);
    void onPosition(qint64 ms);
    PlaybackController *m_pc;
    UndoStack *m_undo;
    LyricsDoc m_doc;
    QVariantList m_lines;
    QString m_raw, m_source = "none";
    qint64 m_id = 0;
    int m_line = -1;
};