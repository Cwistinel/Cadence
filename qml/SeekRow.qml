import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

RowLayout {
    id: s
    spacing: 10
    function fmt(ms) { var t = Math.max(0, Math.floor(ms / 1000)); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    Label { Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: theme.muted; text: s.fmt(bar.scrubbing ? bar.scrubPosition : pc.position) }
    WavySeekbar {
        id: bar
        Layout.fillWidth: true; Layout.preferredHeight: 20; Layout.minimumWidth: 100
        enabled: pc.hasTrack
        position: pc.position; duration: pc.duration; playing: pc.playing
        accent: theme.accent; trackColor: theme.muted; thumbColor: theme.text
        onSeekRequested: (ms) => pc.seek(ms)
    }
    Label { Layout.preferredWidth: 34; font.pixelSize: 10; color: theme.muted; text: s.fmt(pc.duration) }
}