#include "Metadata.h"
#include <QCryptographicHash>
#include <QFile>
#include <QUrl>
#include <gst/pbutils/pbutils.h>
#include <taglib/fileref.h>
#include <taglib/tag.h>
#include <taglib/tfile.h>
#include <taglib/tpropertymap.h>
#include <taglib/tvariant.h>

namespace {
QString q(const TagLib::String &s) { return QString::fromUtf8(s.toCString(true)).trimmed(); }

std::optional<double> num(const TagLib::PropertyMap &p, const char *key) {
    const auto it = p.find(key);
    if (it == p.end() || it->second.isEmpty()) return std::nullopt;
    bool ok = false;
    const double v = q(it->second.front()).remove(QStringLiteral("dB"), Qt::CaseInsensitive).trimmed().toDouble(&ok);
    return ok ? std::optional<double>(v) : std::nullopt;
}

bool discover(const QString &path, TagInfo &t) {
    GError *e = nullptr;
    GstDiscoverer *d = gst_discoverer_new(5 * GST_SECOND, &e);
    g_clear_error(&e);
    if (!d) return false;
    GstDiscovererInfo *i = gst_discoverer_discover_uri(d, QUrl::fromLocalFile(path).toEncoded().constData(), &e);
    g_clear_error(&e);
    bool ok = false;
    if (i) {
        GList *a = gst_discoverer_info_get_audio_streams(i);
        ok = a && gst_discoverer_info_get_result(i) == GST_DISCOVERER_OK;
        if (ok) {
            t.durationMs = gst_discoverer_info_get_duration(i) / GST_MSECOND;
            if (const GstTagList *tl = gst_discoverer_info_get_tags(i)) {
                auto tag = [&](const char *k) { gchar *s = nullptr; QString r; if (gst_tag_list_get_string(tl, k, &s)) { r = QString::fromUtf8(s); g_free(s); } return r; };
                t.title = tag(GST_TAG_TITLE); t.artist = tag(GST_TAG_ARTIST); t.album = tag(GST_TAG_ALBUM);
            }
        }
        gst_discoverer_stream_info_list_free(a);
        g_object_unref(i);
    }
    g_object_unref(d);
    return ok && t.durationMs > 0;
}
}  // namespace

TagInfo Metadata::read(const QString &path) {
    TagInfo t;
    const TagLib::FileRef f(QFile::encodeName(path).constData());
    if (!f.isNull() && f.file() && f.audioProperties() && f.audioProperties()->lengthInMilliseconds() > 0) {
        TagLib::PropertyMap p = f.file()->properties();
        if (const TagLib::Tag *g = f.tag()) {
            t.title = q(g->title()); t.artist = q(g->artist()); t.album = q(g->album()); t.genre = q(g->genre());
            t.trackNo = int(g->track()); t.year = int(g->year());
        }
        if (p.contains("ALBUMARTIST")) t.albumArtist = q(p["ALBUMARTIST"].toString(", "));
        t.durationMs = f.audioProperties()->lengthInMilliseconds();
        t.rgTrack = num(p, "REPLAYGAIN_TRACK_GAIN"); t.rgAlbum = num(p, "REPLAYGAIN_ALBUM_GAIN");
        t.peakTrack = num(p, "REPLAYGAIN_TRACK_PEAK"); t.peakAlbum = num(p, "REPLAYGAIN_ALBUM_PEAK");
        if (!t.rgTrack) if (auto r = num(p, "R128_TRACK_GAIN")) t.rgTrack = *r / 256.0 + 5.0;   // Opus: Q7.8 dB relative to -23 LUFS
        if (!t.rgAlbum) if (auto r = num(p, "R128_ALBUM_GAIN")) t.rgAlbum = *r / 256.0 + 5.0;
        t.ok = true;
    } else {
        t = TagInfo();
        t.ok = discover(path, t);
    }
    return t;
}

QByteArray Metadata::cover(const QString &path) {
    const TagLib::FileRef f(QFile::encodeName(path).constData(), false);
    if (f.isNull() || !f.file()) return {};
    for (const auto &m : f.file()->complexProperties("PICTURE")) {
        const TagLib::ByteVector v = m.value("data").toByteVector();
        if (!v.isEmpty()) return QByteArray(v.data(), int(v.size()));
    }
    return {};
}

QString Metadata::quickHash(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    constexpr qint64 N = 65536;
    QCryptographicHash h(QCryptographicHash::Sha1);
    h.addData(QByteArray::number(f.size()));
    h.addData(f.read(N));
    if (f.size() > 2 * N) { f.seek(f.size() - N); h.addData(f.read(N)); }
    return QString::fromLatin1(h.result().toHex());
}