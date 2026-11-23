#include "TestEnv.h"
#include "Database.h"
#include "LibraryModel.h"

// 10,000 rows go straight into SQLite (no audio files): this measures the query/model layer, not tag reading.
class TstBulk : public QObject {
    Q_OBJECT
private slots:
    void tenThousandTracks() {
        QVERIFY(Database::open());
        QSqlDatabase db = Database::get();
        db.transaction();
        QSqlQuery q(db);
        q.prepare("INSERT INTO tracks(path,dir,title,artist,album,genre,duration_ms,added_at) VALUES(?,?,?,?,?,?,?,?)");
        for (int i = 0; i < 10000; ++i) {
            q.bindValue(0, QString("/bulk/%1/t%2.mp3").arg(i / 100).arg(i)); q.bindValue(1, QString("/bulk/%1").arg(i / 100));
            q.bindValue(2, i % 100 == 0 ? QString("needle %1").arg(i) : QString("Song %1").arg(i));
            q.bindValue(3, QString("Artist %1").arg(i % 200)); q.bindValue(4, QString("Album %1").arg(i / 10));
            q.bindValue(5, QString("Genre %1").arg(i % 7)); q.bindValue(6, 180000 + i); q.bindValue(7, 1);
            QVERIFY(q.exec());
        }
        QVERIFY(db.commit());

        QElapsedTimer t; t.start();
        LibraryModel m;
        m.reload();
        QCOMPARE(m.rowCount(), 300);                                        // lazy: first page only
        while (m.canFetchMore({})) m.fetchMore({});
        QCOMPARE(m.rowCount(), 10000);
        const qint64 all = t.restart();

        m.setFilters(QVariantMap{{"text", "needle"}}); m.reload();
        QCOMPARE(m.total(), 100);
        const qint64 search = t.restart();

        m.setFilters(QVariantMap()); m.setMode("albums"); m.reload();
        QCOMPARE(m.total(), 1000);
        m.setMode("artists"); m.reload();
        QCOMPARE(m.total(), 200);
        const qint64 groups = t.elapsed();

        qInfo() << "load all (ms):" << all << " search (ms):" << search << " albums+artists (ms):" << groups;
        QVERIFY(all < 3000 && search < 1000 && groups < 2000);              // generous: catches accidental full-table disasters, not micro-regressions
    }
};

CADENCE_TEST_MAIN(TstBulk)
#include "tst_bulk.moc"