#include "TestEnv.h"
#include "CueParser.h"

class TstCue : public QObject {
    Q_OBJECT
private slots:
    void parsesSheet() {
        const CueSheet s = CueParser::parse(
            "REM GENRE Rock\nREM DATE 1999\nPERFORMER \"The Band\"\nTITLE \"The Album\"\nFILE \"album.flac\" WAVE\n"
            "  TRACK 01 AUDIO\n    TITLE \"One\"\n    INDEX 01 00:00:00\n"
            "  TRACK 02 AUDIO\n    TITLE \"Two\"\n    PERFORMER \"Guest\"\n    INDEX 00 03:05:00\n    INDEX 01 03:07:38\n");
        QVERIFY2(s.error.isEmpty(), qPrintable(s.error));
        QCOMPARE(s.tracks.size(), 2);
        QCOMPARE(s.title, QString("The Album")); QCOMPARE(s.performer, QString("The Band")); QCOMPARE(s.genre, QString("Rock")); QCOMPARE(s.year, 1999);
        QCOMPARE(s.tracks[1].file, QString("album.flac")); QCOMPARE(s.tracks[1].performer, QString("Guest"));
        QCOMPARE(s.tracks[1].index00, qint64(185000)); QCOMPARE(s.tracks[1].index01, qint64(187506));   // 38 frames = 506 ms
    }
    void rejectsMalformed_data() {
        QTest::addColumn<QByteArray>("cue");
        QTest::newRow("non-audio track") << QByteArray("FILE \"a.wav\" WAVE\nTRACK 01 MODE1/2352\nINDEX 01 00:00:00\n");
        QTest::newRow("track before file") << QByteArray("TRACK 01 AUDIO\nINDEX 01 00:00:00\n");
        QTest::newRow("missing index 01") << QByteArray("FILE \"a.wav\" WAVE\nTRACK 01 AUDIO\nTITLE \"x\"\n");
        QTest::newRow("bad time") << QByteArray("FILE \"a.wav\" WAVE\nTRACK 01 AUDIO\nINDEX 01 00:99:00\n");
        QTest::newRow("out of order") << QByteArray("FILE \"a.wav\" WAVE\nTRACK 01 AUDIO\nINDEX 01 01:00:00\nTRACK 02 AUDIO\nINDEX 01 00:30:00\n");
        QTest::newRow("empty") << QByteArray("");
    }
    void rejectsMalformed() { QFETCH(QByteArray, cue); QVERIFY(!CueParser::parse(cue).error.isEmpty()); }
};

CADENCE_TEST_MAIN(TstCue)
#include "tst_cue.moc"