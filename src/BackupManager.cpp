#include "BackupManager.h"
#include "Database.h"
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QStandardPaths>
#include <QUuid>
#include <QUrl>

namespace {
const QStringList kTables{"folders", "tracks", "overrides", "lyrics", "playlists", "playlist_items", "queue", "history", "settings"};
QString local(const QString &s) { return s.startsWith("file:") ? QUrl(s).toLocalFile() : s; }
QString lit(QString s) { s.replace('\'', "''"); return '\'' + s + '\''; }
QVariantMap fail(const QString &e) { return {{"ok", false}, {"error", e}}; }
}  // namespace

QString BackupManager::backupDir() const { return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/backups"; }
bool BackupManager::exists(const QString &p) const { return QFileInfo::exists(local(p)); }
QString BackupManager::checkIntegrity() const { return Database::integrityCheck(); }

// ---------- create ----------

QVariantMap BackupManager::create(const QString &target, bool overwrite) {
    const QString dest = local(target), tmp = dest + ".tmp";
    if (QFileInfo::exists(dest) && !overwrite) return fail("exists");
    if (!QDir().mkpath(QFileInfo(dest).absolutePath())) return fail(tr("Can't create the destination folder"));
    m_pc->saveNow();                                           // queue and position are written lazily: make them current
    QFile::remove(tmp);
    if (!Database::run("VACUUM INTO " + lit(tmp)).isActive()) return fail(tr("Could not write the backup"));
    const QString conn = QStringLiteral("bk-w-") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool ok = false;
    {   // preferences + marker go into the copy, never into the live database
        QSqlDatabase b = QSqlDatabase::addDatabase("QSQLITE", conn);
        b.setDatabaseName(tmp);
        if (b.open()) {
            QSqlQuery q(b);
            q.exec("PRAGMA journal_mode=DELETE");              // single self-contained file (USB/FAT friendly)
            b.transaction();
            q.prepare("INSERT OR REPLACE INTO settings(key,value) VALUES(?,?)");
            auto put = [&](const QString &k, const QString &v) { q.bindValue(0, k); q.bindValue(1, v); q.exec(); };
            put("backup/app", "cadence");
            put("backup/created", QDateTime::currentDateTime().toString(Qt::ISODate));
            const QVariantMap all = m_set->all();
            for (auto it = all.begin(); it != all.end(); ++it) put("pref/" + it.key(), it.value().toString());
            ok = b.commit();
            q.finish();
        }
        b.close();
    }
    QSqlDatabase::removeDatabase(conn);
    if (!ok) { QFile::remove(tmp); return fail(tr("Could not write the backup")); }
    QFile::remove(dest);
    if (!QFile::rename(tmp, dest)) { QFile::remove(tmp); return fail(tr("Could not save %1").arg(dest)); }
    return {{"ok", true}, {"path", dest}};
}

void BackupManager::autoBackup() {
    const QString d = backupDir(), f = d + "/auto-" + QDate::currentDate().toString("yyyyMMdd") + ".cadbak";
    if (QFileInfo::exists(f)) return;
    create(f, false);
    QStringList old = QDir(d).entryList({"auto-*.cadbak"}, QDir::Files, QDir::Name);
    while (old.size() > 5) QFile::remove(d + '/' + old.takeFirst());
}

// ---------- validate ----------

QVariantMap BackupManager::inspect(const QString &url) const {
    const QString p = local(url);
    if (!QFileInfo(p).isFile()) return fail(tr("File not found"));
    int mine = 0;
    if (QSqlQuery m = Database::run("PRAGMA user_version"); m.next()) mine = m.value(0).toInt();
    QString err, created;
    int tracks = 0, playlists = 0;
    const QString conn = QStringLiteral("bk-r-") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    {
        QSqlDatabase b = QSqlDatabase::addDatabase("QSQLITE", conn);
        b.setDatabaseName(p);
        b.setConnectOptions("QSQLITE_OPEN_READONLY");
        if (!b.open()) err = tr("Not a readable backup");
        else {
            QSqlQuery q(b);
            if (!q.exec("PRAGMA integrity_check") || !q.next() || q.value(0).toString() != "ok") err = tr("The backup file is damaged");
            else {
                q.exec("PRAGMA user_version");
                const int v = q.next() ? q.value(0).toInt() : -1;
                QSet<QString> names;
                q.exec("SELECT name FROM sqlite_master WHERE type='table'");
                while (q.next()) names << q.value(0).toString();
                if (v != mine) err = tr("This backup was made by an incompatible version of Cadence");
                else for (const QString &t : kTables) if (!names.contains(t)) err = tr("Not a Cadence backup");
                if (err.isEmpty()) {
                    q.exec("SELECT value FROM settings WHERE key='backup/app'");
                    if (!q.next() || q.value(0).toString() != "cadence") err = tr("Not a Cadence backup");
                }
                if (err.isEmpty()) {
                    q.exec("SELECT value FROM settings WHERE key='backup/created'"); created = q.next() ? q.value(0).toString() : QString();
                    q.exec("SELECT COUNT(*) FROM tracks WHERE missing=0"); tracks = q.next() ? q.value(0).toInt() : 0;
                    q.exec("SELECT COUNT(*) FROM playlists"); playlists = q.next() ? q.value(0).toInt() : 0;
                }
            }
        }
        b.close();
    }
    QSqlDatabase::removeDatabase(conn);
    if (!err.isEmpty()) return fail(err);
    return {{"ok", true}, {"created", created}, {"tracks", tracks}, {"playlists", playlists}};
}

// ---------- restore ----------

void BackupManager::syncMissing() {   // restored rows may point at files that don't exist on this machine: hide them, keep their data
    QList<QPair<qint64, int>> upd;
    QHash<QString, bool> seen;
    QSqlQuery q = Database::run("SELECT id,path,missing FROM tracks");
    while (q.next()) {
        const QString p = q.value(1).toString();
        if (!seen.contains(p)) seen.insert(p, QFile::exists(p));
        if (seen.value(p) == q.value(2).toBool()) upd << qMakePair(q.value(0).toLongLong(), seen.value(p) ? 0 : 1);
    }
    q.finish();
    QSqlDatabase db = Database::get();
    db.transaction();
    for (const auto &u : upd) Database::run("UPDATE tracks SET missing=? WHERE id=?", {u.second, u.first});
    db.commit();
}

QVariantMap BackupManager::restore(const QString &url) {
    const QString p = local(url);
    const QVariantMap info = inspect(url);
    if (!info["ok"].toBool()) return info;
    if (m_lib->scanning()) return fail(tr("Wait for the library scan to finish, then try again"));

    m_pc->stop();
    const QString safety = backupDir() + "/pre-restore-" + QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss") + ".cadbak";
    if (!create(safety, false)["ok"].toBool()) return fail(tr("Could not save a safety copy of the current data. Nothing was changed."));

    if (!Database::run("ATTACH DATABASE " + lit(p) + " AS bk").isActive()) return fail(tr("Could not open the backup"));
    Database::run("PRAGMA foreign_keys=OFF");                  // must be set outside the transaction
    QSqlDatabase db = Database::get();
    db.transaction();
    bool ok = true;
    for (const QString &t : kTables)
        ok = ok && Database::run("DELETE FROM main." + t).isActive() && Database::run("INSERT INTO main." + t + " SELECT * FROM bk." + t).isActive();
    QVariantMap prefs;
    if (ok) {
        {
            QSqlQuery q = Database::run("SELECT substr(key,6),value FROM main.settings WHERE key LIKE 'pref/%'");
            while (q.next()) prefs[q.value(0).toString()] = q.value(1);
        }
        ok = Database::run("DELETE FROM main.settings WHERE key LIKE 'pref/%' OR key LIKE 'backup/%'").isActive();
    }
    if (ok) ok = db.commit(); else db.rollback();              // any failure leaves the existing data untouched
    Database::run("PRAGMA foreign_keys=ON");
    Database::run("DETACH DATABASE bk");
    if (!ok) return fail(tr("Restore failed. Your existing data was not changed."));

    if (!prefs.isEmpty()) m_set->replaceAll(prefs);
    syncMissing();
    m_undo->clear();
    m_pc->reloadFromDatabase();
    m_lib->reloadFolders();
    emit m_lib->libraryChanged();
    emit restored();
    m_lib->rescanAll();                                        // reconcile with what is actually on disk
    return {{"ok", true}, {"safetyCopy", safety}};
}

// ---------- corruption handling ----------

QString BackupManager::recover() {
    if (Database::integrityCheck() == "ok") return "ok";
    Database::run("PRAGMA wal_checkpoint(TRUNCATE)");
    QFile::copy(Database::path(), Database::path() + ".corrupt-" + QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss"));   // never discard the damaged file
    Database::run("REINDEX");
    const QString again = Database::integrityCheck();
    if (again == "ok") return "ok";
    return tr("The database is damaged and could not be repaired automatically (%1). A copy of the damaged file was kept next to it. Restore a backup from %2.")
        .arg(again.section('\n', 0, 0), backupDir());
}