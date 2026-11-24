#include "LibraryModel.h"
#include "Database.h"
#include "LibraryScanner.h"
#include "PlaybackController.h"
#include <QDate>
#include <QDateTime>
#include <QFileInfo>
#include <QLocale>

namespace {
constexpr int kPage = 300;

struct Shape { QString cols, group; };
Shape shape(const QString &m) {
    const QString tail = QStringLiteral(",MAX(last_played),MAX(added_at),MAX(year)");
    if (m == "albums") return {QStringLiteral("MIN(id),album,CASE WHEN album_artist<>'' THEN album_artist WHEN COUNT(DISTINCT artist)=1 THEN MIN(artist) ELSE '' END,album,album_artist,MIN(dir),COUNT(*),0,SUM(duration_ms),0") + tail, " GROUP BY album,album_artist"};
    if (m == "artists") return {QStringLiteral("MIN(id),artist,artist,'','',MIN(dir),COUNT(*),COUNT(DISTINCT album),SUM(duration_ms),0") + tail, " GROUP BY artist"};
    if (m == "folders") return {QStringLiteral("MIN(id),dir,'','','',dir,COUNT(*),0,SUM(duration_ms),0") + tail, " GROUP BY dir"};
    return {"id,title,artist,album,album_artist,dir,1,track_no,duration_ms,favorite,last_played,added_at,year", ""};
}

QString order(const QString &m, const QString &s, bool desc) {
    QStringList t;
    if (m == "songs") {
        if (s == "artist") t = {"artist COLLATE NOCASE", "album COLLATE NOCASE", "track_no"};
        else if (s == "album") t = {"album COLLATE NOCASE", "track_no"};
        else if (s == "duration") t = {"duration_ms"};
        else if (s == "added") t = {"added_at"};
        else if (s == "played") t = {"last_played"};
        else if (s == "plays") t = {"play_count"};
        else if (s == "trackNo") t = {"track_no"};
        else t = {"title COLLATE NOCASE"};
        t << "id";
    } else {
        if (s == "count") t = {"COUNT(*)"};
        else if (s == "added") t = {"MAX(added_at)"};
        else if (s == "played") t = {"MAX(last_played)"};
        else t = {m == "albums" ? "lower(album)" : m == "artists" ? "lower(artist)" : "lower(dir)"};
        t << "MIN(id)";
    }
    return t.join(desc ? " DESC," : ",") + (desc ? " DESC" : "");
}
}  // namespace

LibraryModel::LibraryModel(QObject *p) : QAbstractListModel(p) {
    m_defer.setSingleShot(true);
    connect(&m_defer, &QTimer::timeout, this, &LibraryModel::reload);   // coalesces several property changes into one query
    if (s_scan) connect(s_scan, &LibraryScanner::libraryChanged, this, [this] { m_defer.start(300); });
    if (s_play) connect(s_play, &PlaybackController::trackUpdated, this, &LibraryModel::refreshRow);
    m_defer.start(0);
}

void LibraryModel::setMode(const QString &m) {
    if (m == m_mode || !QStringList{"songs", "albums", "artists", "folders"}.contains(m)) return;
    m_mode = m; emit modeChanged(); m_defer.start(0);
}

QHash<int, QByteArray> LibraryModel::roleNames() const {
    return {{TrackIdRole, "trackId"}, {TitleRole, "title"}, {ArtistRole, "artist"}, {AlbumRole, "album"}, {AlbumArtistRole, "albumArtist"},
            {FolderRole, "folder"}, {CountRole, "count"}, {ExtraRole, "extra"}, {DurationRole, "durationMs"}, {FavoriteRole, "favorite"},
            {PlayedRole, "playedAt"}, {AddedRole, "addedAt"}, {YearRole, "year"}, {SectionRole, "section"}};
}

QVariant LibraryModel::data(const QModelIndex &ix, int role) const {
    if (!ix.isValid() || ix.row() >= m_rows.size()) return {};
    const Row &r = m_rows.at(ix.row());
    switch (role) {
    case TrackIdRole: return r.id;
    case TitleRole: return m_mode == "folders" ? QFileInfo(r.title).fileName() : r.title;
    case ArtistRole: return r.artist;
    case AlbumRole: return r.album;
    case AlbumArtistRole: return r.albumArtist;
    case FolderRole: return r.dir;
    case CountRole: return r.count;
    case ExtraRole: return r.extra;
    case DurationRole: return r.durationMs;
    case FavoriteRole: return r.favorite;
    case PlayedRole: return r.played;
    case AddedRole: return r.added;
    case YearRole: return r.year;
    case SectionRole: {
        const qint64 ts = m_sort == "added" ? r.added : r.played;
        if (ts <= 0) return tr("Earlier");
        const QDate d = QDateTime::fromSecsSinceEpoch(ts).date(), today = QDate::currentDate();
        return d == today ? tr("Today") : d == today.addDays(-1) ? tr("Yesterday") : QLocale().toString(d, QStringLiteral("MMMM d"));
    }
    }
    return {};
}

QVariantMap LibraryModel::get(int row) const {
    QVariantMap m;
    if (row < 0 || row >= m_rows.size()) return m;
    const auto names = roleNames();
    for (auto it = names.cbegin(); it != names.cend(); ++it) m.insert(QString::fromUtf8(it.value()), data(index(row), it.key()));
    return m;
}

QString LibraryModel::sectionAt(int row) const { return row < 0 || row >= m_rows.size() ? QString() : data(index(row), SectionRole).toString(); }

LibraryModel::Row LibraryModel::readRow(const QSqlQuery &q) {   // column order = Shape::cols
    return {q.value(0).toLongLong(), q.value(1).toString(), q.value(2).toString(), q.value(3).toString(), q.value(4).toString(), q.value(5).toString(),
            q.value(6).toInt(), q.value(7).toInt(), q.value(8).toLongLong(), q.value(9).toBool(), q.value(10).toLongLong(), q.value(11).toLongLong(), q.value(12).toInt()};
}

QString LibraryModel::where(const QVariantMap &f, QVariantList &a) {
    QStringList c;
    for (const QString &w : f.value("text").toString().split(' ', Qt::SkipEmptyParts)) {
        const QString like = '%' + QString(w).replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_") + '%';
        c << "(title LIKE ? ESCAPE '\\' OR artist LIKE ? ESCAPE '\\' OR album LIKE ? ESCAPE '\\' OR genre LIKE ? ESCAPE '\\')";
        a << like << like << like << like;
    }
    auto eq = [&](const char *key, const char *col) { if (f.contains(key)) { c << QString::fromLatin1(col) + "=?"; a << f.value(key).toString(); } };
    eq("artist", "artist"); eq("album", "album"); eq("albumArtist", "album_artist"); eq("genre", "genre");
    if (f.contains("folder")) {
        QString d = f.value("folder").toString();
        while (d.size() > 1 && d.endsWith('/')) d.chop(1);
        c << "(dir=? OR substr(dir,1,length(?)+1)=?||'/')"; a << d << d << d;
    }
    if (f.contains("minDuration")) { c << "duration_ms>=?"; a << f.value("minDuration").toLongLong() * 1000; }
    if (f.contains("maxDuration")) { c << "duration_ms<=?"; a << f.value("maxDuration").toLongLong() * 1000; }
    if (f.value("favorite").toBool()) c << "favorite=1";
    if (f.value("recentlyAdded").toBool()) { c << "added_at>=?"; a << QDateTime::currentSecsSinceEpoch() - 30 * 86400; }
    if (f.value("recentlyPlayed").toBool()) c << "last_played>0";
    if (f.contains("minPlays")) { c << "play_count>=?"; a << f.value("minPlays").toInt(); }
    return c.isEmpty() ? QStringLiteral("1") : c.join(" AND ");
}

void LibraryModel::reload() {
    m_defer.stop();
    QVariantList a;
    const QString w = where(m_filters, a);
    const Shape s = shape(m_mode);
    QSqlQuery q = Database::run(s.group.isEmpty() ? "SELECT COUNT(*) FROM v_tracks WHERE " + w : "SELECT COUNT(*) FROM (SELECT 1 FROM v_tracks WHERE " + w + s.group + ")", a);
    int total = q.next() ? q.value(0).toInt() : 0;
    if (m_limit > 0) total = qMin(total, m_limit);
    beginResetModel(); m_rows.clear(); m_total = total; endResetModel();
    if (canFetchMore({})) fetchMore({});
    emit totalChanged();                                   // after the first page is in: QML can read get(0) right away
}

void LibraryModel::fetchMore(const QModelIndex &) {
    QVariantList a;
    const QString w = where(m_filters, a);
    const Shape s = shape(m_mode);
    int want = kPage;
    if (m_limit > 0) want = qMin(want, m_limit - int(m_rows.size()));
    if (want <= 0) return;
    a << want << int(m_rows.size());
    QSqlQuery q = Database::run("SELECT " + s.cols + " FROM v_tracks WHERE " + w + s.group + " ORDER BY " + order(m_mode, m_sort, m_desc) + " LIMIT ? OFFSET ?", a);
    QList<Row> add;
    while (q.next()) add << readRow(q);
    if (add.isEmpty()) { m_total = int(m_rows.size()); emit totalChanged(); return; }   // library shrank under us
    beginInsertRows({}, int(m_rows.size()), int(m_rows.size() + add.size()) - 1);
    m_rows += add;
    endInsertRows();
}

void LibraryModel::refreshRow(qint64 id) {   // favorite/play-count/metadata changes: update in place, no reset (keeps scroll position)
    if (m_mode != "songs") return;
    for (int i = 0; i < m_rows.size(); ++i) {
        if (m_rows[i].id != id) continue;
        QSqlQuery q = Database::run("SELECT " + shape("songs").cols + " FROM v_tracks WHERE id=?", {id});
        if (q.next()) { m_rows[i] = readRow(q); emit dataChanged(index(i), index(i)); }
        return;
    }
}

QVariantList LibraryModel::idsFor(int row) const {
    if (row < 0 || row >= m_rows.size()) return {};
    const Row &r = m_rows.at(row);
    if (m_mode == "songs") return {r.id};
    QVariantMap g;   // only the group's own key: playing an album plays all of it, even if a search matched part of it
    if (m_mode == "albums") { g["album"] = r.album; g["albumArtist"] = r.albumArtist; }
    else if (m_mode == "artists") g["artist"] = r.artist;
    else g["folder"] = r.dir;
    QVariantList a, out;
    QSqlQuery q = Database::run("SELECT id FROM v_tracks WHERE " + where(g, a) + " ORDER BY album COLLATE NOCASE, track_no, title COLLATE NOCASE, start_ms", a);
    while (q.next()) out << q.value(0);
    return out;
}

QVariantList LibraryModel::allIds() const {
    QVariantList a, out;
    const QString o = m_mode == "songs" ? order("songs", m_sort, m_desc) : QStringLiteral("album COLLATE NOCASE, track_no, title COLLATE NOCASE, start_ms");
    QSqlQuery q = Database::run("SELECT id FROM v_tracks WHERE " + where(m_filters, a) + " ORDER BY " + o, a);
    while (q.next()) out << q.value(0);
    return out;
}

QStringList LibraryModel::distinct(const QString &c) const { return distinctWhere(c, {}); }

QStringList LibraryModel::distinctWhere(const QString &c, const QVariantMap &f) const {
    if (!QStringList{"genre", "artist", "album"}.contains(c)) return {};
    QVariantList a;
    const QString w = where(f, a);
    QStringList out;
    QSqlQuery q = Database::run("SELECT DISTINCT " + c + " FROM v_tracks WHERE " + c + "<>'' AND " + w + " ORDER BY lower(" + c + ")", a);
    while (q.next()) out << q.value(0).toString();
    return out;
}