import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: np
    readonly property var app: Window.window
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 24; spacing: 0

        Item {   // artwork pane
            Layout.fillWidth: false; Layout.fillHeight: true
            Layout.preferredWidth: (np.width - 24) / 2.15
            Cover {
                anchors.centerIn: parent
                width: Math.max(120, Math.min(parent.width - 24, parent.height - 24, 480)); height: width
                trackId: pc.track.id || 0; px: 640; corner: 0.07
            }
        }

        ColumnLayout {   // controls + metadata
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 12; Layout.rightMargin: 32
            spacing: 0
            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 30; font.weight: Font.ExtraBold; font.letterSpacing: -0.35; text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing") }
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 17; font.weight: Font.Medium; color: theme.subtext; text: pc.hasTrack ? pc.track.artist + (pc.track.album ? " — " + pc.track.album : "") : "" }
                }
                IconButton { size: 50; tonal: true; glyph: pc.track.favorite ? "♥" : "♡"; enabled: pc.hasTrack; color: pc.track.favorite ? theme.accent : theme.text; tip: qsTr("Favorite"); onClicked: pc.toggleFavorite() }
                IconButton { size: 50; tonal: true; glyph: "≣"; tip: qsTr("Lyrics"); onClicked: np.app.showPage("lyrics") }
            }

            Item { Layout.preferredHeight: 20 }
            SeekRow { Layout.fillWidth: true }
            Item { Layout.preferredHeight: 14 }

            RowLayout {   // main controls: circle, wide pill, circle
                Layout.alignment: Qt.AlignHCenter; spacing: 18
                IconButton { Layout.alignment: Qt.AlignVCenter; size: 54; tonal: true; icon: "prev"; enabled: pc.canPrevious; tip: qsTr("Previous"); onClicked: pc.previous() }
                Item {
                    id: pill
                    Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 160; Layout.preferredHeight: 64
                    Rectangle {
                        anchors.fill: parent; radius: height / 2; color: theme.accent
                        opacity: pma.pressed ? 0.85 : 1
                        scale: pma.pressed ? 0.97 : 1
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 500 } }
                    }
                    Icon { anchors.centerIn: parent; width: 30; height: 30; name: pc.playing ? "pause" : "play"; color: theme.onAccent }
                    MouseArea {
                        id: pma; anchors.fill: parent; hoverEnabled: true
                        onClicked: pc.togglePlayPause()
                        ToolTip.visible: containsMouse; ToolTip.text: qsTr("Play / Pause"); ToolTip.delay: 600
                    }
                }
                IconButton { Layout.alignment: Qt.AlignVCenter; size: 54; tonal: true; icon: "next"; enabled: pc.canNext; tip: qsTr("Next"); onClicked: pc.next() }
            }

            Item { Layout.preferredHeight: 30 }

            RowLayout {   // utility row
                Layout.alignment: Qt.AlignHCenter; spacing: 10
                IconButton { size: 44; tonal: true; glyph: "⇄"; color: pc.shuffle ? theme.accent : theme.text; tip: qsTr("Shuffle"); onClicked: pc.shuffle = !pc.shuffle }
                IconButton { size: 44; tonal: true; glyph: pc.repeat === 2 ? "↻¹" : "↻"; color: pc.repeat > 0 ? theme.accent : theme.text; tip: qsTr("Repeat"); onClicked: pc.repeat = (pc.repeat + 1) % 3 }
                IconButton { size: 44; tonal: true; glyph: "☰"; color: np.app.rightPanel ? theme.accent : theme.text; tip: qsTr("Queue (Q)"); onClicked: np.app.rightPanel = !np.app.rightPanel }
                IconButton { size: 44; tonal: true; glyph: "✎"; enabled: pc.hasTrack; tip: qsTr("Edit info"); onClicked: np.app.openMeta(pc.track.id) }
                VolumeControl { Layout.leftMargin: 8 }
            }
            Item { Layout.fillHeight: true }
        }
    }
}