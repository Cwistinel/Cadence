#pragma once
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>
#include <QtTest>

// Every test runs against a throw-away XDG tree, never your real ~/.local/share/cadence.
struct TestEnv {
    QTemporaryDir dir;
    TestEnv() {
        const QString d = dir.path();
        qputenv("XDG_DATA_HOME", (d + "/data").toUtf8()); qputenv("XDG_CONFIG_HOME", (d + "/config").toUtf8());
        qputenv("XDG_CACHE_HOME", (d + "/cache").toUtf8()); qputenv("CADENCE_TEST_DIR", (d + "/work").toUtf8());
    }
};
inline QString work() { return qEnvironmentVariable("CADENCE_TEST_DIR"); }

// Silent 16-bit mono PCM WAV of a given length (a real, decodable audio file).
inline void writeWav(const QString &path, int seconds, int rate = 8000) {
    const quint32 n = quint32(seconds) * rate * 2;
    QByteArray h("RIFF");
    auto le = [&](quint32 v, int b) { for (int i = 0; i < b; ++i) h.append(char((v >> (8 * i)) & 0xFF)); };
    le(36 + n, 4); h += "WAVEfmt "; le(16, 4); le(1, 2); le(1, 2); le(rate, 4); le(rate * 2, 4); le(2, 2); le(16, 2); h += "data"; le(n, 4);
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly)) { f.write(h); f.write(QByteArray(int(n), '\0')); }
}

#define CADENCE_TEST_MAIN(T) \
    int main(int argc, char **argv) { TestEnv env; QCoreApplication app(argc, argv); app.setApplicationName("cadence"); T t; return QTest::qExec(&t, argc, argv); }
