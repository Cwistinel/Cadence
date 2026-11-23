#include "TestEnv.h"
#include "LyricsManager.h"

class TstLyrics : public QObject {
    Q_OBJECT
private slots:
    void parsesSortsAndStripsWordTags() {
        const LyricsDoc d = LyricsManager::parse("[ar:Someone]\n[00:12.34]A\n[00:01.5]B <00:02.00>C\n");
        QVERIFY(d.synced); QCOMPARE(d.lines.size(), 2); QCOMPARE(d.meta, QStringList{"[ar:Someone]"});
        QCOMPARE(d.lines[0].ms, qint64(1500)); QCOMPARE(d.lines[0].text, QString("B C"));
        QCOMPARE(d.lines[1].ms, qint64(12340));
    }
    void roundTripIsLossless() {
        for (const char *s : {"[00:01.50]x\n[00:12.34]y", "[00:01.234]x", "[ar:Z]\n[10:00.00]long"}) {
            const QString in = QString::fromLatin1(s);
            QCOMPARE(LyricsManager::format(LyricsManager::parse(in)), in);
        }
    }
    void multipleStampsAndOffset() {
        const LyricsDoc d = LyricsManager::parse("[offset:500]\n[00:02.00][00:04.00]chorus");
        QCOMPARE(d.lines.size(), 2); QCOMPARE(d.lines[0].ms, qint64(1500)); QCOMPARE(d.lines[1].ms, qint64(3500));
    }
    void unsynchronized() {
        const LyricsDoc d = LyricsManager::parse("\nline1\n\nline2\n\n");
        QVERIFY(!d.synced); QCOMPARE(d.lines.size(), 3); QCOMPARE(d.lines[2].text, QString("line2"));
    }
};

CADENCE_TEST_MAIN(TstLyrics)
#include "tst_lyrics.moc"