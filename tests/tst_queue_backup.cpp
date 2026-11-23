#include "TestEnv.h"
#include "AudioEngine.h"
#include "BackupManager.h"
#include "Database.h"
#include "LibraryScanner.h"
#include "PlaybackController.h"

// Queue logic is tested through enqueue() only, so no audio pipeline is ever opened here.
class TstQueueBackup : public QObject {
    Q_OBJECT
    QList<qint64> ids;
    Settings *set; UndoStack *undo; AudioEngine *eng; PlaybackController *pc; LibraryScanner *sc;
    QVariantList L(std::initializer_list<int> ix) const { QVariantList l; for (int i : ix) l << ids[i]; return l; }
    static int one(const QString &sql, const QVariantList &a = {}) { QSqlQuery q = Database::run(sql, a); return q.next() ? q.value(0).toInt() : -1; }
private slots:
    void initTestCase() {
        QVERIFY(Database::open());
        for (int i = 0; i < 5; ++i) {
            const QString p = work() + QString("/t%1.wav").arg(i);
            writeWav(p, 1);
            ids << Database::run("INSERT INTO tracks(path,dir,title,artist,album,duration_ms,added_at) VALUES(?,?,?,?,?,1000,1)", {p, work(), QString("T%1").arg(i), "A", "B"}).lastInsertId().toLongLong();
        }
        set = new Settings(this); undo = new UndoStack(this); eng = new AudioEngine(this);
        pc = new PlaybackController(eng, set, undo, this); sc = new LibraryScanner(this);
    }
    void enqueueDedupesAndSelectsFirst() {
        pc->enqueue(L({0, 1, 2, 0}));
        QCOMPARE(pc->queue()->count(), 3); QVERIFY(pc->hasTrack());
        QCOMPARE(pc->currentTrack().id, ids[0]); QCOMPARE(pc->state(), 0);
    }
    void removeAndUndo() {
        pc->removeAt(1);
        QCOMPARE(pc->queue()->count(), 2); QVERIFY(undo->canUndo());
        undo->undo();
        QCOMPARE(pc->queue()->count(), 3); QCOMPARE(pc->queue()->at(1).id, ids[1]);
    }
    void reorderKeepsCurrentAndUndoes() {
        pc->moveTrack(0, 2);
        QCOMPARE(pc->currentIndex(), 2); QCOMPARE(pc->currentTrack().id, ids[0]);
        undo->undo();
        QCOMPARE(pc->queue()->at(0).id, ids[0]); QCOMPARE(pc->currentIndex(), 0);
    }
    void playNextAndShuffleKeepCurrent() {
        pc->enqueue(L({3}), true);
        QCOMPARE(pc->queue()->at(pc->currentIndex() + 1).id, ids[3]);
        pc->setShuffle(true);
        QCOMPARE(pc->currentTrack().id, ids[0]);
        pc->enqueue(L({4}), true);
        QCOMPARE(pc->queue()->at(pc->currentIndex() + 1).id, ids[4]);
        pc->setShuffle(false);
        QCOMPARE(pc->queue()->count(), 5);
    }
    void favoriteUndo() {
        pc->setFavorite(ids[1], true);
        QCOMPARE(one("SELECT favorite FROM tracks WHERE id=?", {ids[1]}), 1);
        undo->undo();
        QCOMPARE(one("SELECT favorite FROM tracks WHERE id=?", {ids[1]}), 0);
    }
    void backupRoundTrip() {
        BackupManager b(pc, sc, set, undo);
        pc->setFavorite(ids[2], true);
        set->setValue("ui/theme", "dark");
        const int n = pc->queue()->count();
        const QString f = work() + "/b.cadbak";
        QVERIFY(b.create(f)["ok"].toBool());
        QCOMPARE(b.create(f)["error"].toString(), QString("exists"));       // never overwrites without confirmation
        const QVariantMap info = b.inspect(f);
        QVERIFY(info["ok"].toBool()); QCOMPARE(info["tracks"].toInt(), 5);
        QCOMPARE(Database::integrityCheck(), QString("ok"));

        pc->setFavorite(ids[2], false); set->setValue("ui/theme", "light"); pc->clearQueue();
        const QVariantMap r = b.restore(f);
        QVERIFY2(r["ok"].toBool(), qPrintable(r["error"].toString()));
        QVERIFY(QFile::exists(r["safetyCopy"].toString()));
        QCOMPARE(one("SELECT favorite FROM tracks WHERE id=?", {ids[2]}), 1);
        QCOMPARE(set->text("ui/theme"), QString("dark"));
        QCOMPARE(pc->queue()->count(), n);
    }
    void damagedBackupIsRejected() {
        BackupManager b(pc, sc, set, undo);
        QFile f(work() + "/bad.cadbak");
        QVERIFY(f.open(QIODevice::WriteOnly)); f.write("not a database at all, just text"); f.close();
        QVERIFY(!b.inspect(f.fileName())["ok"].toBool());
        QVERIFY(!b.restore(f.fileName())["ok"].toBool());
        QCOMPARE(one("SELECT COUNT(*) FROM v_tracks"), 5);                  // nothing changed
    }
};

CADENCE_TEST_MAIN(TstQueueBackup)
#include "tst_queue_backup.moc"