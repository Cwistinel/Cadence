import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: mp
    signal expand()
    transientParent: null
    flags: Qt.Window | Qt.WindowStaysOnTopHint
    width: 480; height: 196
    minimumWidth: 440; minimumHeight: 190
    title: "Cadence"
    color: theme.bg
    Behavior on color { ColorAnimation { duration: 500 } }
    onClosing: (close) => { if (desktop.closeToTray()) { close.accepted = false; hide() } else Qt.quit() }
    // Maximize (or full screen) leaves mini-player mode and returns to the main window.
    onVisibilityChanged: if (visibility === Window.Maximized || visibility === Window.FullScreen) { visibility = Window.Windowed; mp.expand() }
    palette { window: theme.bg; windowText: theme.text; base: theme.surface; text: theme.text; button: theme.surface; buttonText: theme.text; highlight: theme.accent; highlightedText: theme.onAccent }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 6

        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Cover { Layout.preferredWidth: 84; Layout.preferredHeight: 84; Layout.alignment: Qt.AlignTop; trackId: pc.track.id || 0; px: 192; corner: 0.2 }
            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 2
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: -0.2; text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing") }
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: theme.subtext; text: pc.hasTrack ? pc.track.artist : "" }
            }
            IconButton { Layout.alignment: Qt.AlignTop; size: 34; tonal: true; glyph: "⤢"; tip: qsTr("Open main window"); onClicked: mp.expand() }
        }

        SeekRow { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Item { Layout.fillWidth: true }
            PlayerControls { size: 34 }
            Item { Layout.fillWidth: true }
            VolumeControl { sliderWidth: 72 }
        }
    }
}