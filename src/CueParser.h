#pragma once
#include <QByteArray>
#include <QList>
#include <QString>

struct CueTrack {
    int number = 0;
    QString file, title, performer;
    qint64 index00 = -1, index01 = -1, pregap = 0;   // ms; -1 = absent
};

struct CueSheet {
    QString title, performer, genre, error;           // non-empty error = rejected sheet
    int year = 0;
    QList<CueTrack> tracks;                           // sheet order; each track carries its FILE
};

namespace CueParser {
CueSheet parse(const QByteArray &data);               // never throws; check .error
}