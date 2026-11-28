#include "TestEnv.h"
#include "Database.h"
#include "LibraryScanner.h"
#include <QDirIterator>

// Slots run in declaration order and share state on purpose: scan -> move -> delete -> untouched originals.
class TstLibrary : public QObject {
    Q_OBJECT
    QString root;
    LibraryScanner *sc = nullptr;
    QMap<QString, QString> before;
    static int count(const QString &sql, const QVariantList &a = {}) { QSqlQuery q = Database::run(sql, a); return q.next() ? q.value(0).toInt() : -1; }
    static QMap<QString, QString> state(const QString &dir) {
        QMap<QString, QString> m;
        QDirIterator it(dir, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) { it.next(); m[it.filePath()] = QString::number(it.fileInfo().size()) + "|" + QString::number(it.fileInfo().lastModified().toMSecsSinceEpoch()); }
        return m;
    }
    void scanWait(const QString &p) { QSignalSpy s(sc, &LibraryScanner::scanFinished); sc->rescan(p); QVERIFY(s.wait(20000)); }
private slots:
    void initTestCase() {
        QVERIFY(Database::open());
        root = work() + "/music";
        writeWav(root + "/a.wav", 1); writeWav(root + "/b.wav", 2); writeWav(root + "/album/disc.wav", 6);
        QFile c(root + "/album/disc.cue");
        QVERIFY(c.open(QIODevice::WriteOnly));
        c.write("PERFORMER \"Band\"\nTITLE \"Live\"\nFILE \"disc.wav\" WAVE\n TRACK 01 AUDIO\n  TITLE \"One\"\n  INDEX 01 00:00:00\n"
                " TRACK 02 AUDIO\n  TITLE \"Two\"\n  INDEX 01 00:02:00\n TRACK 03 AUDIO\n  TITLE \"Three\"\n  INDEX 01 00:04:00\n");
        c.close();
        before = state(root + "/album");
        sc = new LibraryScanner(this);
        QSignalSpy s(sc, &LibraryScanner::scanFinished);
        sc->addFolder(root);
        QVERIFY(s.wait(20000));
    }
    void scansFilesAndCueTracks() {
        const QString disc = root + "/album/disc.wav";
        QCOMPARE(count("SELECT COUNT(*) FROM v_tracks"), 5);                                                        // a, b + 3 virtual tracks
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=?", {disc}), 3);
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=? AND start_ms=0 AND end_ms=0", {disc}), 0);        // no independent entry for the physical file
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=? AND start_ms=2000 AND end_ms=4000 AND title='Two' AND duration_ms=2000", {disc}), 1);
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=? AND start_ms=4000 AND end_ms=0 AND duration_ms=2000", {disc}), 1);   // last track runs to EOF
    }
    void movedFileKeepsIdAndFavorite() {
        const qint64 id = count("SELECT id FROM tracks WHERE path=?", {root + "/a.wav"});
        QVERIFY(id > 0);
        Database::run("UPDATE tracks SET favorite=1 WHERE id=?", {id});
        QDir().mkpath(root + "/sub");
        QVERIFY(QFile::rename(root + "/a.wav", root + "/sub/a2.wav"));
        scanWait(root);
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE id=? AND path=? AND missing=0 AND favorite=1", {id, root + "/sub/a2.wav"}), 1);
        QCOMPARE(count("SELECT COUNT(*) FROM v_tracks"), 5);
    }
    void deletedFileIsHiddenNotDeleted_andReturns() {
        const QString b = root + "/b.wav";
        QVERIFY(QFile::remove(b));
        scanWait(root);
        QCOMPARE(count("SELECT COUNT(*) FROM v_tracks"), 4);
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=? AND missing=1", {b}), 1);
        writeWav(b, 2);
        scanWait(root);
        QCOMPARE(count("SELECT COUNT(*) FROM v_tracks"), 5);
        QCOMPARE(count("SELECT COUNT(*) FROM tracks WHERE path=?", {b}), 1);                                        // same row came back
    }
    void originalsAreUntouched() { QCOMPARE(state(root + "/album"), before); }
    void duplicatesToleranceGroupsCloseLengths() {
        writeWav(root + "/dup1/song.wav", 6); writeWav(root + "/dup2/song.wav", 7);
        scanWait(root);
        QVERIFY(!sc->duplicates(5000).isEmpty());   // 1 s apart: same 5 s bucket
        QVERIFY(sc->duplicates(1000).isEmpty());    // different 1 s buckets
    }
};

CADENCE_TEST_MAIN(TstLibrary)
#include "tst_library.moc"