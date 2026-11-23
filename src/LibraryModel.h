#pragma once
#include <QAbstractListModel>
#include <QTimer>
#include <QVariantMap>
#include <QSqlQuery>

class LibraryScanner;
class PlaybackController;

// One class, four views: mode = songs | albums | artists | folders. Instantiate one per QML view.
// filters (all optional, combined with AND): text, artist, album, albumArtist, genre, folder (recursive), minDuration/maxDuration (seconds),
//   favorite (bool), recentlyAdded (bool, last 30 days), recentlyPlayed (bool), minPlays (int)
// sort: songs -> title|artist|album|duration|added|played|plays|trackNo; others -> title|count|added
// Rows load lazily in pages of 300 through canFetchMore/fetchMore.
class LibraryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QVariantMap filters READ filters WRITE setFilters NOTIFY filtersChanged)
    Q_PROPERTY(QString sort READ sort WRITE setSort NOTIFY sortChanged)
    Q_PROPERTY(bool descending READ descending WRITE setDescending NOTIFY sortChanged)
    Q_PROPERTY(int total READ total NOTIFY totalChanged)          // all matching rows, not just the loaded ones
public:
    enum Role { TrackIdRole = Qt::UserRole + 1, TitleRole, ArtistRole, AlbumRole, AlbumArtistRole, FolderRole, CountRole, ExtraRole, DurationRole, FavoriteRole };
    // extra: songs = track number, artists = album count. count: tracks in the group (1 for songs). trackId: the song, or the first track of the group (for artwork).
    static void setSources(LibraryScanner *s, PlaybackController *p) { s_scan = s; s_play = p; }   // call once before creating views
    explicit LibraryModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &p = {}) const override { return p.isValid() ? 0 : int(m_rows.size()); }
    QVariant data(const QModelIndex &ix, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    bool canFetchMore(const QModelIndex &p) const override { return !p.isValid() && m_rows.size() < m_total; }
    void fetchMore(const QModelIndex &p) override;

    QString mode() const { return m_mode; }
    QVariantMap filters() const { return m_filters; }
    QString sort() const { return m_sort; }
    bool descending() const { return m_desc; }
    int total() const { return m_total; }
    void setMode(const QString &m);
    void setFilters(const QVariantMap &f) { if (f == m_filters) return; m_filters = f; emit filtersChanged(); m_defer.start(0); }
    void setSort(const QString &s) { if (s == m_sort) return; m_sort = s; emit sortChanged(); m_defer.start(0); }
    void setDescending(bool d) { if (d == m_desc) return; m_desc = d; emit sortChanged(); m_defer.start(0); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore() { if (canFetchMore({})) fetchMore({}); }
    Q_INVOKABLE QVariantList idsFor(int row) const;                // every track behind a row, in album order
    Q_INVOKABLE QVariantList allIds() const;                       // every track matching filters, in the current sort
    Q_INVOKABLE QStringList distinct(const QString &column) const; // "genre" | "artist" | "album" values for filter pickers

signals:
    void modeChanged();
    void filtersChanged();
    void sortChanged();
    void totalChanged();

private:
    struct Row { qint64 id = 0; QString title, artist, album, albumArtist, dir; int count = 0, extra = 0; qint64 durationMs = 0; bool favorite = false; };
    static Row readRow(const QSqlQuery &q);
    static QString where(const QVariantMap &f, QVariantList &a);
    void refreshRow(qint64 id);

    inline static LibraryScanner *s_scan = nullptr;
    inline static PlaybackController *s_play = nullptr;
    QList<Row> m_rows;
    QString m_mode = "songs", m_sort = "title";
    QVariantMap m_filters;
    bool m_desc = false;
    int m_total = 0;
    QTimer m_defer;
};