import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: r
    property real size: 44
    spacing: 6
    IconButton { Layout.alignment: Qt.AlignVCenter; size: r.size * 0.8; glyph: "⇄"; active: pc.shuffle; color: pc.shuffle ? theme.accent : theme.subtext; tip: qsTr("Shuffle"); onClicked: pc.shuffle = !pc.shuffle }
    IconButton { Layout.alignment: Qt.AlignVCenter; size: r.size; icon: "prev"; enabled: pc.canPrevious; tip: qsTr("Previous"); onClicked: pc.previous() }
    Item {   // play/pause: rounded square while paused, circle while playing
        id: pb
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: r.size * 1.25; Layout.preferredHeight: r.size * 1.25
        Rectangle {
            anchors.fill: parent
            radius: pc.playing ? width / 2 : width * 0.32
            color: theme.accent
            opacity: pma.pressed ? 0.85 : 1
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 500 } }
        }
        Icon { anchors.centerIn: parent; width: pb.width * 0.5; height: width; name: pc.playing ? "pause" : "play"; color: theme.onAccent }
        MouseArea {
            id: pma; anchors.fill: parent; hoverEnabled: true
            onClicked: pc.togglePlayPause()
            ToolTip.visible: containsMouse; ToolTip.text: qsTr("Play / Pause"); ToolTip.delay: 600
        }
    }
    IconButton { Layout.alignment: Qt.AlignVCenter; size: r.size; icon: "next"; enabled: pc.canNext; tip: qsTr("Next"); onClicked: pc.next() }
    IconButton {
        Layout.alignment: Qt.AlignVCenter
        size: r.size * 0.8; glyph: pc.repeat === 2 ? "↻¹" : "↻"; active: pc.repeat > 0
        color: pc.repeat > 0 ? theme.accent : theme.subtext; tip: qsTr("Repeat"); onClicked: pc.repeat = (pc.repeat + 1) % 3
    }
    IconButton {
        Layout.alignment: Qt.AlignVCenter
        size: r.size * 0.8; glyph: pc.track.favorite ? "♥" : "♡"; enabled: pc.hasTrack
        color: pc.track.favorite ? theme.accent : theme.subtext; tip: qsTr("Favorite"); onClicked: pc.toggleFavorite()
    }
}