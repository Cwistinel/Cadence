#include "Database.h"
#include <QDebug>
#include <QDir>
#include <QSqlError>
#include <QStandardPaths>

namespace {
constexpr int kVersion = 1;

QString connName(const QString &c) { return c.isEmpty() ? QString::fromLatin1(QSqlDatabase::defaultConnection) : c; }

// Rows are never hard-deleted when a file disappears (missing=1), so user data (lyrics, overrides, favorites) survives.
const char *kSchemaV1[] = {
R"(CREATE TABLE IF NOT EXISTS folders(id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, monitored INTEGER NOT NULL DEFAULT 1))",
R"(CREATE TABLE IF NOT EXISTS tracks(
  id INTEGER PRIMARY KEY,
  path TEXT NOT NULL, start_ms INTEGER NOT NULL DEFAULT 0, end_ms INTEGER NOT NULL DEFAULT 0,
  folder_id INTEGER, dir TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL DEFAULT '', artist TEXT NOT NULL DEFAULT '', album TEXT NOT NULL DEFAULT '',
  album_artist TEXT NOT NULL DEFAULT '', genre TEXT NOT NULL DEFAULT '',
  track_no INTEGER NOT NULL DEFAULT 0, year INTEGER NOT NULL DEFAULT 0,
  duration_ms INTEGER NOT NULL DEFAULT 0, mtime INTEGER NOT NULL DEFAULT 0, size INTEGER NOT NULL DEFAULT 0,
  hash TEXT NOT NULL DEFAULT '',
  rg_track REAL, rg_album REAL, peak_track REAL, peak_album REAL,
  cue_path TEXT NOT NULL DEFAULT '',
  added_at INTEGER NOT NULL DEFAULT 0, favorite INTEGER NOT NULL DEFAULT 0,
  play_count INTEGER NOT NULL DEFAULT 0, last_played INTEGER NOT NULL DEFAULT 0,
  missing INTEGER NOT NULL DEFAULT 0,
  UNIQUE(path, start_ms)))",
"CREATE INDEX IF NOT EXISTS i_tracks_artist ON tracks(artist)",
"CREATE INDEX IF NOT EXISTS i_tracks_album ON tracks(album)",
"CREATE INDEX IF NOT EXISTS i_tracks_genre ON tracks(genre)",
"CREATE INDEX IF NOT EXISTS i_tracks_title ON tracks(title)",
"CREATE INDEX IF NOT EXISTS i_tracks_dir ON tracks(dir)",
"CREATE INDEX IF NOT EXISTS i_tracks_hash ON tracks(hash)",
"CREATE INDEX IF NOT EXISTS i_tracks_fav ON tracks(favorite)",
"CREATE INDEX IF NOT EXISTS i_tracks_added ON tracks(added_at)",
"CREATE INDEX IF NOT EXISTS i_tracks_played ON tracks(last_played)",
"CREATE INDEX IF NOT EXISTS i_tracks_count ON tracks(play_count)",
"CREATE INDEX IF NOT EXISTS i_tracks_missing ON tracks(missing)",
R"(CREATE TABLE IF NOT EXISTS overrides(track_id INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE,
  title TEXT, artist TEXT, album TEXT, album_artist TEXT, genre TEXT, track_no INTEGER))",
R"(CREATE TABLE IF NOT EXISTS lyrics(track_id INTEGER PRIMARY KEY REFERENCES tracks(id) ON DELETE CASCADE, content TEXT NOT NULL))",
R"(CREATE TABLE IF NOT EXISTS playlists(id INTEGER PRIMARY KEY, name TEXT NOT NULL))",
R"(CREATE TABLE IF NOT EXISTS playlist_items(id INTEGER PRIMARY KEY,
  playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE, pos INTEGER NOT NULL))",
"CREATE INDEX IF NOT EXISTS i_pl_items ON playlist_items(playlist_id, pos)",
R"(CREATE TABLE IF NOT EXISTS queue(pos INTEGER PRIMARY KEY, track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE))",
R"(CREATE TABLE IF NOT EXISTS history(id INTEGER PRIMARY KEY, track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE, played_at INTEGER NOT NULL))",
"CREATE INDEX IF NOT EXISTS i_history_time ON history(played_at)",
R"(CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT))",   // only used inside backups
R"(CREATE VIEW IF NOT EXISTS v_tracks AS SELECT t.id, t.path, t.start_ms, t.end_ms, t.dir, t.folder_id,
  COALESCE(o.title, t.title) AS title, COALESCE(o.artist, t.artist) AS artist, COALESCE(o.album, t.album) AS album,
  COALESCE(o.album_artist, t.album_artist) AS album_artist, COALESCE(o.genre, t.genre) AS genre,
  COALESCE(o.track_no, t.track_no) AS track_no, t.year, t.duration_ms, t.rg_track, t.rg_album, t.peak_track, t.peak_album,
  t.cue_path, t.added_at, t.favorite, t.play_count, t.last_played, t.hash, t.mtime, t.size
  FROM tracks t LEFT JOIN overrides o ON o.track_id = t.id WHERE t.missing = 0)",
};

bool migrate(QSqlDatabase db) {
    QSqlQuery q(db);
    q.exec("PRAGMA user_version");
    if ((q.next() ? q.value(0).toInt() : 0) >= kVersion) return true;
    db.transaction();
    for (const char *s : kSchemaV1)
        if (!q.exec(QString::fromUtf8(s))) { qWarning() << "Schema error:" << q.lastError().text(); db.rollback(); return false; }
    q.exec(QStringLiteral("PRAGMA user_version=%1").arg(kVersion));
    return db.commit();
}
}  // namespace

QString Database::path() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/library.db";
}

bool Database::open(const QString &c, QString *err) {
    const QString n = connName(c);
    QSqlDatabase db = QSqlDatabase::contains(n) ? QSqlDatabase::database(n, false) : QSqlDatabase::addDatabase("QSQLITE", n);
    db.setDatabaseName(path());
    if (!db.open()) { if (err) *err = db.lastError().text(); return false; }
    QSqlQuery q(db);
    for (const char *p : {"PRAGMA journal_mode=WAL", "PRAGMA foreign_keys=ON", "PRAGMA synchronous=NORMAL", "PRAGMA busy_timeout=5000"}) q.exec(QString::fromLatin1(p));
    if (!migrate(db)) { if (err) *err = "schema migration failed"; return false; }
    return true;
}

QSqlDatabase Database::get(const QString &c) { return QSqlDatabase::database(connName(c)); }

void Database::close(const QString &c) {
    const QString n = connName(c);
    { QSqlDatabase db = QSqlDatabase::database(n, false); if (db.isOpen()) db.close(); }
    QSqlDatabase::removeDatabase(n);
}

QSqlQuery Database::run(const QString &sql, const QVariantList &args, const QString &c) {
    QSqlQuery q(get(c));
    q.prepare(sql);
    for (const QVariant &a : args) q.addBindValue(a);
    if (!q.exec()) qWarning() << "SQL failed:" << q.lastError().text() << "|" << sql;
    return q;
}

QString Database::integrityCheck(const QString &c) {
    QSqlQuery q = run("PRAGMA integrity_check", {}, c);
    QStringList rows;
    while (q.next() && rows.size() < 5) rows << q.value(0).toString();
    return rows.isEmpty() ? QStringLiteral("unreadable database") : rows.join('\n');
}