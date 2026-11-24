#pragma once
#include <QAbstractListModel>
#include <QSqlQuery>
#include <QTimer>
#include <QVariantMap>

class LibraryScanner;
class PlaybackController;

// One class, four views: mode = songs | albums | artists | folders. Instantiate one per QML view.
// filters (all optional, combined with AND): text, artist, album, albumArtist, genre, folder (recursive), minDuration/maxDuration (seconds),
//   favorite (bool), recentlyAdded (bool, last 30 days), recentlyPlayed (bool), minPlays (int)
// sort: songs -> title|artist|album|duration|added|played|plays|trackNo; others -> title|count|added|played
// Rows load lazily in pages of 300. limit > 0 caps the number of rows.
class LibraryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QVariantMap filters READ filters WRITE setFilters NOTIFY filtersChanged)
    Q_PROPERTY(QString sort READ sort WRITE setSort NOTIFY sortChanged)
    Q_PROPERTY(bool descending READ descending WRITE setDescending NOTIFY sortChanged)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged)
    Q_PROPERTY(int total READ total NOTIFY totalChanged)          // matching rows (capped by limit), not just the loaded ones
public:
    enum Role { TrackIdRole = Qt::UserRole + 1, TitleRole, ArtistRole, AlbumRole, AlbumArtistRole, FolderRole, CountRole, ExtraRole, DurationRole, FavoriteRole,
                PlayedRole, AddedRole, YearRole, SectionRole };
    // extra: songs = track number, artists = album count. count: tracks in the group (1 for songs). trackId: the song, or the first track of the group (for artwork).
    // section: "Today" / "Yesterday" / "March 3", from the played time (sort=played) or the added time (otherwise).
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
    int limit() const { return m_limit; }
    int total() const { return m_total; }
    void setMode(const QString &m);
    void setFilters(const QVariantMap &f) { if (f == m_filters) return; m_filters = f; emit filtersChanged(); m_defer.start(0); }
    void setSort(const QString &s) { if (s == m_sort) return; m_sort = s; emit sortChanged(); m_defer.start(0); }
    void setDescending(bool d) { if (d == m_desc) return; m_desc = d; emit sortChanged(); m_defer.start(0); }
    void setLimit(int l) { if (l == m_limit) return; m_limit = l; emit limitChanged(); m_defer.start(0); }

    Q_INVOKABLE void reload();
    Q_INVOKABLE void loadMore() { if (canFetchMore({})) fetchMore({}); }
    Q_INVOKABLE QVariantMap get(int row) const;                    // every role of a loaded row, by role name
    Q_INVOKABLE QString sectionAt(int row) const;
    Q_INVOKABLE QVariantList idsFor(int row) const;                // every track behind a row, in album order
    Q_INVOKABLE QVariantList allIds() const;                       // every track matching filters, in the current sort
    Q_INVOKABLE QStringList distinct(const QString &column) const; // "genre" | "artist" | "album" values for filter pickers
    Q_INVOKABLE QStringList distinctWhere(const QString &column, const QVariantMap &filters) const;

signals:
    void modeChanged();
    void filtersChanged();
    void sortChanged();
    void limitChanged();
    void totalChanged();

private:
    struct Row { qint64 id = 0; QString title, artist, album, albumArtist, dir; int count = 0, extra = 0; qint64 durationMs = 0; bool favorite = false; qint64 played = 0, added = 0; int year = 0; };
    static Row readRow(const QSqlQuery &q);
    static QString where(const QVariantMap &f, QVariantList &a);
    void refreshRow(qint64 id);

    inline static LibraryScanner *s_scan = nullptr;
    inline static PlaybackController *s_play = nullptr;
    QList<Row> m_rows;
    QString m_mode = "songs", m_sort = "title";
    QVariantMap m_filters;
    bool m_desc = false;
    int m_total = 0, m_limit = 0;
    QTimer m_defer;
};