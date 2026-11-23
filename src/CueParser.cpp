#include "CueParser.h"
#include <QHash>
#include <QStringList>

namespace {
QStringList tokens(const QString &s) {   // whitespace-separated, double quotes group words
    QStringList out; QString cur; bool inQ = false, has = false;
    for (const QChar c : s) {
        if (c == QLatin1Char('"')) { inQ = !inQ; has = true; }
        else if (c.isSpace() && !inQ) { if (has) { out << cur; cur.clear(); has = false; } }
        else { cur += c; has = true; }
    }
    if (has) out << cur;
    return out;
}

qint64 msf(const QString &t, bool *ok) {   // mm:ss:ff (75 frames per second)
    const QStringList p = t.split(':');
    bool a = false, b = false, c = false;
    const int mm = p.size() == 3 ? p[0].toInt(&a) : 0, ss = p.size() == 3 ? p[1].toInt(&b) : 0, ff = p.size() == 3 ? p[2].toInt(&c) : 0;
    *ok = a && b && c && mm >= 0 && ss >= 0 && ss < 60 && ff >= 0 && ff < 75;
    return (mm * 60LL + ss) * 1000 + ff * 1000 / 75;
}
}  // namespace

CueSheet CueParser::parse(const QByteArray &data) {
    CueSheet s;
    QString text = QString::fromUtf8(data);
    if (text.contains(QChar::ReplacementCharacter)) text = QString::fromLatin1(data);   // legacy 8-bit sheets
    if (text.startsWith(QChar(0xFEFF))) text.remove(0, 1);

    QString file;
    int cur = -1, lineNo = 0;
    for (const QString &raw : text.split('\n')) {
        ++lineNo;
        const QStringList t = tokens(raw.trimmed());
        if (t.isEmpty()) continue;
        const QString c = t[0].toUpper();
        auto fail = [&](const QString &m) { s.error = QStringLiteral("line %1: %2").arg(lineNo).arg(m); };
        if (c == "FILE") {
            if (t.size() < 2) { fail("FILE without a name"); return s; }
            file = t.size() > 2 ? t.mid(1, t.size() - 2).join(' ') : t[1];
        } else if (c == "TRACK") {
            if (t.size() < 3 || t[2].toUpper() != "AUDIO") { fail("unsupported TRACK (only AUDIO is supported)"); return s; }
            if (file.isEmpty()) { fail("TRACK before FILE"); return s; }
            CueTrack k; k.number = t[1].toInt(); k.file = file;
            s.tracks << k; cur = int(s.tracks.size()) - 1;
        } else if (c == "TITLE" || c == "PERFORMER") {
            const QString v = t.mid(1).join(' ');
            QString &dst = cur < 0 ? (c == "TITLE" ? s.title : s.performer) : (c == "TITLE" ? s.tracks[cur].title : s.tracks[cur].performer);
            dst = v;
        } else if (c == "REM" && t.size() > 2 && cur < 0) {
            const QString k = t[1].toUpper(), v = t.mid(2).join(' ');
            if (k == "GENRE") s.genre = v; else if (k == "DATE") s.year = v.left(4).toInt();
        } else if (c == "INDEX" || c == "PREGAP") {
            if (cur < 0) { fail(c + " before TRACK"); return s; }
            bool ok = false;
            const qint64 ms = msf(t.value(c == "INDEX" ? 2 : 1), &ok);
            if (!ok) { fail("invalid time value"); return s; }
            CueTrack &k = s.tracks[cur];
            const QString n = t.value(1);
            if (c == "PREGAP") k.pregap = ms; else if (n == "00") k.index00 = ms; else if (n == "01") k.index01 = ms;
        }
    }
    if (s.tracks.isEmpty()) { s.error = QStringLiteral("no tracks"); return s; }
    QHash<QString, qint64> last;
    for (const CueTrack &k : s.tracks) {
        if (k.index01 < 0) { s.error = QStringLiteral("track %1 has no INDEX 01").arg(k.number); return s; }
        if (last.contains(k.file) && k.index01 <= last[k.file]) { s.error = QStringLiteral("track %1: indexes out of order").arg(k.number); return s; }
        last[k.file] = k.index01;
    }
    return s;
}