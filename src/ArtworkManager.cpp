#include "ArtworkManager.h"
#include "Database.h"
#include "Metadata.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QSet>
#include <QStandardPaths>
#include <QThread>
#include <QPainterPath>
namespace {
constexpr int kMax = 512;

struct ThreadDb {   // one SQLite connection per calling thread (QML image thread, worker threads, GUI thread)
    QString name = QStringLiteral("art-") + QString::number(quintptr(QThread::currentThread()), 16);
    bool ok = Database::open(name);
    ~ThreadDb() { Database::close(name); }
};
struct Src { QString path, dir, key; };

bool lookup(qint64 id, Src &s) {
    thread_local ThreadDb db;
    if (!db.ok) return false;
    QSqlQuery q = Database::run("SELECT path,mtime FROM tracks WHERE id=?", {id}, db.name);
    if (!q.next()) return false;
    s.path = q.value(0).toString();
    s.dir = QFileInfo(s.path).absolutePath();
    s.key = QString::fromLatin1(QCryptographicHash::hash((s.path + '|' + q.value(1).toString()).toUtf8(), QCryptographicHash::Sha1).toHex().left(24));
    return true;
}

QString external(const QString &dir) {   // cover/folder/front/album(art) next to the track, in that order of preference
    static const QStringList names{"cover", "folder", "front", "album", "albumart"};
    static const QSet<QString> ext{"jpg", "jpeg", "png", "webp"};
    QString best; int rank = 99;
    for (const QFileInfo &f : QDir(dir).entryInfoList(QDir::Files)) {
        if (!ext.contains(f.suffix().toLower())) continue;
        const int r = int(names.indexOf(f.completeBaseName().toLower()));
        if (r >= 0 && r < rank) { rank = r; best = f.absoluteFilePath(); }
    }
    return best;
}

QImage placeholder(int n) {
    QImage i(n, n, QImage::Format_RGB32);
    i.fill(QColor(0x2A, 0x2A, 0x30));
    QPainter p(&i);
    QFont f; f.setPixelSize(n * 2 / 3);
    p.setFont(f); p.setPen(QColor(0x55, 0x55, 0x5E));
    p.drawText(i.rect(), Qt::AlignCenter, QString(QChar(0x266A)));
    return i;
}
}  // namespace

QString ArtworkManager::cacheDir() {
    static const QString d = [] { const QString p = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/art"; QDir().mkpath(p); return p; }();
    return d;
}

QString ArtworkManager::key(qint64 id) { Src s; return lookup(id, s) ? s.key : QString(); }

QImage ArtworkManager::image(qint64 id) {
    Src s;
    if (!lookup(id, s)) return {};
    const QString base = cacheDir() + '/' + s.key;
    if (QFile::exists(base + ".jpg")) { const QImage c(base + ".jpg"); if (!c.isNull()) return c; }
    if (QFile::exists(base + ".none")) return {};

    QImage img;
    if (const QByteArray b = Metadata::cover(s.path); !b.isEmpty()) img.loadFromData(b);
    if (img.isNull()) if (const QString e = external(s.dir); !e.isEmpty()) img.load(e);
    if (img.isNull()) { QFile m(base + ".none"); m.open(QIODevice::WriteOnly); return {}; }   // remembered: never retried

    if (qMax(img.width(), img.height()) > kMax) img = img.scaled(kMax, kMax, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    img = img.convertToFormat(QImage::Format_RGB32);
    img.save(base + ".jpg", "JPG", 88);
    return img;
}

QImage ArtProvider::requestImage(const QString &id, QSize *size, const QSize &req) {
    QImage img = ArtworkManager::image(id.section('?', 0, 0).toLongLong());
    const int rw = req.width() > 0 ? req.width() : 1 << 20, rh = req.height() > 0 ? req.height() : 1 << 20;
    if (img.isNull()) img = placeholder(qBound(32, qMin(rw, rh), 512));
    else if (rw < img.width() || rh < img.height()) img = img.scaled(rw, rh, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const double r = id.section('?', 1).mid(2).toDouble();     // "?r=0.2": corner radius as a fraction of the side (0 = square, 0.5 = circle)
    if (r > 0) {
        const int s = qMin(img.width(), img.height());
        const QImage sq = img.copy((img.width() - s) / 2, (img.height() - s) / 2, s, s);
        QImage out(s, s, QImage::Format_ARGB32_Premultiplied);
        out.fill(Qt::transparent);
        QPainter p(&out);
        p.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
        QPainterPath path; path.addRoundedRect(QRectF(0, 0, s, s), s * r, s * r);
        p.setClipPath(path);
        p.drawImage(0, 0, sq);
        p.end();
        img = out;
    }
    if (size) *size = img.size();
    return img;
}