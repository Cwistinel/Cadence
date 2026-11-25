#include "AudioEngine.h"
#include <QUrl>
#include <QtMath>

namespace {
QByteArray uriFor(const QString &p) { return QUrl::fromLocalFile(p).toEncoded(); }
bool isAudioSink(GstObject *o) {
    if (!o || !GST_IS_ELEMENT(o)) return false;
    const gchar *k = gst_element_class_get_metadata(GST_ELEMENT_GET_CLASS(o), GST_ELEMENT_METADATA_KLASS);
    return k && g_strrstr(k, "Sink/Audio");
}
}  // namespace

AudioEngine::AudioEngine(QObject *parent) : QObject(parent) {
    gst_init(nullptr, nullptr);
    m_bands = QList<double>(10, 0.0);
    ensureDeck(0);
    m_timer.setInterval(100);
    m_fadeTimer.setInterval(30);
    connect(&m_timer, &QTimer::timeout, this, &AudioEngine::tick);
    connect(&m_fadeTimer, &QTimer::timeout, this, &AudioEngine::fadeStep);
    m_mon = gst_device_monitor_new();
    gst_device_monitor_add_filter(m_mon, "Audio/Sink", nullptr);
    GstBus *b = gst_device_monitor_get_bus(m_mon);
    gst_bus_set_sync_handler(b, &AudioEngine::monSync, this, nullptr);
    gst_object_unref(b);
    gst_device_monitor_start(m_mon);
}

AudioEngine::~AudioEngine() {
    m_timer.stop(); m_fadeTimer.stop();
    GstBus *b = gst_device_monitor_get_bus(m_mon);
    gst_bus_set_sync_handler(b, nullptr, nullptr, nullptr);
    gst_object_unref(b);
    gst_device_monitor_stop(m_mon);
    gst_object_unref(m_mon);
    for (Deck &d : m_deck) if (d.play) {
        g_signal_handlers_disconnect_by_data(d.play, &d.ctx);
        GstBus *bb = gst_element_get_bus(d.play);
        gst_bus_set_sync_handler(bb, nullptr, nullptr, nullptr);
        gst_object_unref(bb);
        gst_element_set_state(d.play, GST_STATE_NULL);
        gst_object_unref(d.play);
    }
}

// ---------- GStreamer plumbing ----------

GstBusSyncReply AudioEngine::busSync(GstBus *, GstMessage *m, gpointer u) {
    auto *c = static_cast<BusCtx *>(u);
    switch (GST_MESSAGE_TYPE(m)) {
    case GST_MESSAGE_ERROR: case GST_MESSAGE_EOS: case GST_MESSAGE_ASYNC_DONE: case GST_MESSAGE_STREAM_START: {
        AudioEngine *e = c->e; const int idx = c->idx, gen = c->gen.load();
        GstMessage *r = gst_message_ref(m);
        QMetaObject::invokeMethod(e, [e, idx, gen, r] {
            if (e->m_deck[idx].ctx.gen.load() == gen) e->onBus(idx, r);
            gst_message_unref(r);
        }, Qt::QueuedConnection);
        break; }
    default: break;
    }
    return GST_BUS_DROP;
}

GstBusSyncReply AudioEngine::monSync(GstBus *, GstMessage *m, gpointer u) {
    const auto t = GST_MESSAGE_TYPE(m);
    if (t == GST_MESSAGE_DEVICE_ADDED || t == GST_MESSAGE_DEVICE_REMOVED) {
        auto *e = static_cast<AudioEngine *>(u);
        QMetaObject::invokeMethod(e, [e] { e->onDevicesChanged(); }, Qt::QueuedConnection);
    }
    return GST_BUS_DROP;
}

void AudioEngine::onAboutToFinish(GstElement *, gpointer u) {
    auto *c = static_cast<BusCtx *>(u);
    QMutexLocker l(&c->e->m_mx);
    if (c->idx != c->e->m_cur) return;
    c->e->aboutToFinish();   // runs on a streaming thread, m_mx already held
}

void AudioEngine::aboutToFinish() {
    if (!m_gapless || !m_next.isValid() || m_next.startMs > 0) return;   // gapless needs a whole-file next item
    if (m_crossfadeMs > 0 && m_curDur > 2LL * m_crossfadeMs) return;    // crossfade owns this transition
    m_advItem = m_next; m_next = PlayItem(); m_advancePending = true;
    g_object_set(m_deck[m_cur].play, "uri", uriFor(m_advItem.path).constData(), nullptr);
}

void AudioEngine::ensureDeck(int i) {
    Deck &d = m_deck[i];
    if (d.play) return;
    d.ctx.e = this; d.ctx.idx = i;
    d.play = gst_element_factory_make("playbin", nullptr);
    if (!d.play) { qCritical("GStreamer 'playbin' is unavailable"); return; }
    gst_util_set_object_arg(G_OBJECT(d.play), "flags", "audio+soft-volume");   // audio only: no video/text/vis
    g_signal_connect(d.play, "about-to-finish", G_CALLBACK(&AudioEngine::onAboutToFinish), &d.ctx);
    GstBus *b = gst_element_get_bus(d.play);
    gst_bus_set_sync_handler(b, &AudioEngine::busSync, &d.ctx, nullptr);
    gst_object_unref(b);
}

void AudioEngine::closeDeck(Deck &d) {
    d.ctx.gen.fetch_add(1);
    d.opening = false; d.pendingSeek = -1;
    if (d.play) gst_element_set_state(d.play, GST_STATE_NULL);
}

void AudioEngine::applySink(Deck &d) {
    GstElement *sink = nullptr;
    if (!m_device.isEmpty()) {
        GList *l = gst_device_monitor_get_devices(m_mon);
        for (GList *i = l; i && !sink; i = i->next) {
            gchar *n = gst_device_get_display_name(GST_DEVICE(i->data));
            if (QString::fromUtf8(n) == m_device) sink = gst_device_create_element(GST_DEVICE(i->data), nullptr);
            g_free(n);
        }
        g_list_free_full(l, gst_object_unref);
    }
    g_object_set(d.play, "audio-sink", sink, nullptr);   // nullptr => playbin picks the default sink
}

// Filters exist only when needed (EQ on, or speed != 1) so the idle path has zero extra processing.
void AudioEngine::applyFilter(Deck &d) {
    QStringList parts;
    if (m_eqOn) parts << "equalizer-10bands name=eq";
    if (m_speed != 1.0) parts << "scaletempo";
    GstElement *bin = nullptr;
    if (!parts.isEmpty()) {
        GError *e = nullptr;
        bin = gst_parse_bin_from_description(("audioconvert ! " + parts.join(" ! ") + " ! audioconvert").toUtf8().constData(), TRUE, &e);
        if (e) g_error_free(e);
    }
    g_object_set(d.play, "audio-filter", bin, nullptr);
    applyBands(d);
}

void AudioEngine::applyBands(Deck &d) {
    if (!d.play || !m_eqOn) return;
    GstElement *f = nullptr;
    g_object_get(d.play, "audio-filter", &f, nullptr);
    if (!f) return;
    if (GstElement *eq = gst_bin_get_by_name(GST_BIN(f), "eq")) {
        for (int i = 0; i < 10 && i < m_bands.size(); ++i)
            g_object_set(eq, QByteArray("band" + QByteArray::number(i)).constData(), qBound(-24.0, m_bands[i], 12.0), nullptr);
        gst_object_unref(eq);
    }
    gst_object_unref(f);
}

void AudioEngine::applyVolume(int i) {
    Deck &d = m_deck[i];
    if (!d.play) return;
    const double v = qPow(m_volume, 3) * qPow(10.0, d.item.gainDb / 20.0) * d.fade;
    g_object_set(d.play, "volume", qBound(0.0, v, 10.0), "mute", (gboolean)m_muted, nullptr);
}

void AudioEngine::doSeek(Deck &d, qint64 absMs) {
    gst_element_seek(d.play, m_speed, GST_FORMAT_TIME, GstSeekFlags(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
                     GST_SEEK_TYPE_SET, absMs * GST_MSECOND, GST_SEEK_TYPE_NONE, GST_CLOCK_TIME_NONE);
}

void AudioEngine::open(int i, const PlayItem &it, qint64 resume, bool play, double fade) {
    ensureDeck(i);
    Deck &d = m_deck[i];
    if (!d.play) { emit error(it.path, "GStreamer playbin is unavailable", true); return; }
    closeDeck(d);
    d.item = it; d.wantPlay = play; d.resume = resume; d.pendingSeek = it.startMs + resume; d.opening = true; d.fade = fade;
    m_advancePending = false;
    applySink(d); applyFilter(d); applyVolume(i);
    g_object_set(d.play, "uri", uriFor(it.path).constData(), nullptr);
    gst_element_set_state(d.play, GST_STATE_PAUSED);   // preroll; ASYNC_DONE continues in onBus()
}

// ---------- bus events (GUI thread) ----------

void AudioEngine::onBus(int i, GstMessage *m) {
    Deck &d = m_deck[i];
    switch (GST_MESSAGE_TYPE(m)) {
    case GST_MESSAGE_ASYNC_DONE:
        if (GST_MESSAGE_SRC(m) != GST_OBJECT(d.play)) break;
        if (d.pendingSeek >= 0 && (d.pendingSeek > 0 || m_speed != 1.0)) { const qint64 s = d.pendingSeek; d.pendingSeek = -1; doSeek(d, s); break; }
        d.pendingSeek = -1;
        if (d.opening) {
            d.opening = false;
            if (d.wantPlay) {
                gst_element_set_state(d.play, GST_STATE_PLAYING);
                if (m_fading && i == m_fadeTo) { m_fadeClock.start(); m_fadeTimer.start(); }
            }
            emit durationChanged();
        }
        break;
    case GST_MESSAGE_STREAM_START:
        if (GST_MESSAGE_SRC(m) != GST_OBJECT(d.play) || i != m_cur || !m_advancePending.exchange(false)) break;
        { PlayItem n; { QMutexLocker l(&m_mx); n = m_advItem; }
          if (!n.isValid()) break;
          d.item = n; m_curDur = n.durationMs; applyVolume(i);
          if (m_speed != 1.0) doSeek(d, n.startMs);   // new stream must pick up the playback rate
          emit durationChanged(); emit advanced(); }
        break;
    case GST_MESSAGE_EOS:
        if (m_fading && i == m_cur) { finishFade(); break; }
        if (i != m_cur) break;
        { const PlayItem n = [&] { QMutexLocker l(&m_mx); PlayItem x = m_next; m_next = PlayItem(); return x; }();
          if (n.isValid()) { play(n, true); emit advanced(); } else { stop(); emit finished(); } }
        break;
    case GST_MESSAGE_ERROR: {
        GError *e = nullptr; gchar *dbg = nullptr;
        gst_message_parse_error(m, &e, &dbg);
        const QString msg = QString::fromUtf8(e ? e->message : "unknown error");
        const bool sinkErr = isAudioSink(GST_MESSAGE_SRC(m));
        g_clear_error(&e); g_free(dbg);
        if (sinkErr && !m_device.isEmpty() && i == m_cur) { m_device.clear(); emit deviceChanged(); reopen(); break; }  // device vanished: fall back to default
        const QString path = d.item.path;
        if (i != m_cur) { cancelFade(); emit error(path, msg, false); break; }
        stop(); emit error(path, msg, true);
        break; }
    default: break;
    }
}

void AudioEngine::onDevicesChanged() {
    emit devicesChanged();
    if (!m_device.isEmpty() && !devices().contains(m_device)) { m_device.clear(); emit deviceChanged(); reopen(); }
}

// ---------- transport ----------

void AudioEngine::setState(State s) {
    if (s == m_state) return;
    m_state = s;
    if (s == Playing) m_timer.start(); else m_timer.stop();
    emit stateChanged();
}

void AudioEngine::play(const PlayItem &it, bool autoplay, qint64 resumeMs) {
    cancelFade();
    const int o = 1 - m_cur;
    if (m_deck[o].play) closeDeck(m_deck[o]);
    m_curDur = it.durationMs;
    open(m_cur, it, resumeMs, autoplay, 1.0);
    setState(autoplay ? Playing : Paused);
    emit durationChanged();
    emit positionChanged(resumeMs);
}

void AudioEngine::setNext(const PlayItem &it) { QMutexLocker l(&m_mx); m_next = it; }

void AudioEngine::applyRun(bool run) {
    for (int i = 0; i < 2; ++i) {
        Deck &d = m_deck[i];
        if (!d.play || (i != m_cur && !(m_fading && i == m_fadeTo))) continue;
        if (d.opening) d.wantPlay = run; else gst_element_set_state(d.play, run ? GST_STATE_PLAYING : GST_STATE_PAUSED);
    }
}

void AudioEngine::pause()  { if (m_state != Playing) return; if (m_fading) finishFade(); applyRun(false); setState(Paused); }
void AudioEngine::resume() { if (m_state != Paused) return; applyRun(true); setState(Playing); }

void AudioEngine::stop() {
    cancelFade();
    for (Deck &d : m_deck) if (d.play) closeDeck(d);
    m_advancePending = false;
    setState(Stopped);
    emit positionChanged(0);
}

void AudioEngine::seek(qint64 ms) {
    if (m_state == Stopped) return;
    if (m_fading) finishFade();
    Deck &d = m_deck[m_cur];
    ms = qMax<qint64>(0, ms);
    if (const qint64 dur = duration(); dur > 0) ms = qMin(ms, dur - 1);
    if (d.opening) { d.pendingSeek = d.item.startMs + ms; d.resume = ms; } else doSeek(d, d.item.startMs + ms);
    m_lastPos = ms;
    emit positionChanged(ms);
}

qint64 AudioEngine::position() const {
    const Deck &d = m_deck[m_cur];
    if (!d.play || m_state == Stopped) return 0;
    if (d.opening) return d.resume;
    gint64 p = 0;
    if (!gst_element_query_position(d.play, GST_FORMAT_TIME, &p)) return m_lastPos;
    return m_lastPos = qMax<qint64>(0, p / GST_MSECOND - d.item.startMs);
}

qint64 AudioEngine::duration() const {
    const Deck &d = m_deck[m_cur];
    if (d.item.durationMs > 0) return d.item.durationMs;
    gint64 t = 0;
    if (d.play && m_state != Stopped && gst_element_query_duration(d.play, GST_FORMAT_TIME, &t)) return qMax<qint64>(0, t / GST_MSECOND - d.item.startMs);
    return 0;
}

// ---------- settings ----------

void AudioEngine::setVolume(double v) { m_volume = qBound(0.0, v, 1.0); applyVolume(0); applyVolume(1); }
void AudioEngine::setMuted(bool m) { m_muted = m; applyVolume(0); applyVolume(1); }

void AudioEngine::setSpeed(double s) {
    s = qBound(0.5, s, 2.0);
    if (qFuzzyCompare(s, m_speed)) return;
    const bool crossing = (m_speed == 1.0) != (s == 1.0);
    m_speed = s;
    if (m_state == Stopped) return;
    if (crossing) reopen();                                    // attaches/detaches scaletempo
    else if (!m_deck[m_cur].opening) doSeek(m_deck[m_cur], m_deck[m_cur].item.startMs + position());
}

void AudioEngine::setEqualizer(bool on, const QList<double> &gains) {
    m_bands = gains;
    if (on != m_eqOn) { m_eqOn = on; reopen(); return; }      // filter is (de)attached on re-open at the same position
    if (on) { applyBands(m_deck[0]); applyBands(m_deck[1]); }
}

void AudioEngine::setDevice(const QString &name) { m_device = name; emit deviceChanged(); reopen(); }

QStringList AudioEngine::devices() const {
    QStringList out;
    GList *l = gst_device_monitor_get_devices(m_mon);
    for (GList *i = l; i; i = i->next) { gchar *n = gst_device_get_display_name(GST_DEVICE(i->data)); out << QString::fromUtf8(n); g_free(n); }
    g_list_free_full(l, gst_object_unref);
    return out;
}

void AudioEngine::reopen() {
    if (m_state == Stopped) return;
    if (m_fading) finishFade();
    open(m_cur, m_deck[m_cur].item, position(), m_state == Playing, 1.0);
}

// ---------- boundaries, gapless continuation, crossfade ----------

void AudioEngine::tick() {
    Deck &d = m_deck[m_cur];
    if (m_state != Playing || d.opening) return;
    const qint64 pos = position(), dur = duration();
    emit positionChanged(pos);
    const qint64 rem = dur > 0 ? dur - pos : INT64_MAX;
    m_timer.setInterval(rem < 400 ? 10 : 100);                 // fine-grained only near a CUE/track boundary
    if (d.item.endMs > 0 && rem <= 15) { reachedEnd(); return; }
    const int xf = m_crossfadeMs;
    if (xf > 0 && !m_fading && dur > 2LL * xf && rem <= xf) {
        const PlayItem n = nextCopy();
        if (n.isValid() && !n.continuesFrom(d.item)) startCrossfade();
    }
}

void AudioEngine::reachedEnd() {   // end of a CUE virtual track inside a longer file
    const PlayItem n = [&] { QMutexLocker l(&m_mx); PlayItem x = m_next; m_next = PlayItem(); return x; }();
    Deck &d = m_deck[m_cur];
    if (!n.isValid()) { stop(); emit finished(); return; }
    if (n.continuesFrom(d.item)) {                              // same file, contiguous: keep playing, just switch metadata
        d.item = n; m_curDur = n.durationMs; applyVolume(m_cur);
        emit durationChanged(); emit advanced();
        return;
    }
    play(n, true); emit advanced();
}

void AudioEngine::startCrossfade() {
    const PlayItem n = [&] { QMutexLocker l(&m_mx); PlayItem x = m_next; m_next = PlayItem(); return x; }();
    if (!n.isValid()) return;
    m_fadeTo = 1 - m_cur;
    m_fading = true;
    open(m_fadeTo, n, 0, true, 0.0);                            // fade clock starts when the incoming deck is actually playing
}

void AudioEngine::fadeStep() {
    const double t = qMin(1.0, m_fadeClock.elapsed() / double(qMax(1, int(m_crossfadeMs))));
    m_deck[m_cur].fade = qCos(t * M_PI_2);                      // equal-power curves: no loudness dip, no jump
    m_deck[m_fadeTo].fade = qSin(t * M_PI_2);
    applyVolume(m_cur); applyVolume(m_fadeTo);
    if (t >= 1.0) finishFade();
}

void AudioEngine::finishFade() {
    if (!m_fading) return;
    m_fadeTimer.stop(); m_fading = false;
    closeDeck(m_deck[m_cur]); m_deck[m_cur].fade = 1.0;
    m_cur = m_fadeTo;
    m_deck[m_cur].fade = 1.0; applyVolume(m_cur);
    m_curDur = m_deck[m_cur].item.durationMs;
    emit durationChanged(); emit advanced();
}

void AudioEngine::cancelFade() {
    if (!m_fading) return;
    m_fadeTimer.stop(); m_fading = false;
    closeDeck(m_deck[m_fadeTo]);
    m_deck[m_cur].fade = 1.0; applyVolume(m_cur);
}