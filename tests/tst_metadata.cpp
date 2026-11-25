#include "TestEnv.h"
#include "Metadata.h"

class TstMetadata : public QObject {
    Q_OBJECT
private slots:
    void formatWav() {
        const QString p = work() + "/t.wav";
        writeWav(p, 1);
        const QString f = Metadata::format(p);
        QVERIFY2(f.startsWith("WAV · "), qPrintable(f));
        QVERIFY(f.contains("kHz"));
    }
};

CADENCE_TEST_MAIN(TstMetadata)
#include "tst_metadata.moc"
