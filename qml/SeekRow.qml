import QtQuick
import QtQuick.Controls
import Cadence 1.0

Item {
    id: s
    implicitHeight: 40
    property color acc: theme.accent
    Behavior on acc { ColorAnimation { duration: 500 } }
    function fmt(ms) { var t = Math.max(0, Math.floor(ms / 1000)); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    Label {
        id: lt
        x: 0; y: s.height - 14 - height / 2; width: 38
        horizontalAlignment: Text.AlignRight; font.pixelSize: 12; color: theme.subtext
        text: s.fmt(bar.scrubbing ? bar.scrubPosition : pc.position)
    }
    WavySeekbar {
        id: bar
        anchors.left: lt.right; anchors.right: rt.left; anchors.top: parent.top
        height: s.height
        enabled: pc.hasTrack
        position: pc.position; duration: pc.duration; playing: pc.playing; accent: s.acc
        trackColor: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.22)
        onSeekRequested: (ms) => pc.seek(ms)
    }
    Label {
        id: rt
        anchors.right: parent.right; y: s.height - 14 - height / 2; width: 38
        font.pixelSize: 12; color: theme.subtext; text: s.fmt(pc.duration)
    }
}