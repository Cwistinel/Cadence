import QtQuick
import QtQuick.Controls

// Figma album / artist tile: artwork, 14 px title, 12 px subtitle (8 px gaps).
Item {
    id: t
    property real size: 192
    property var trackId: 0
    property string title
    property string subtitle
    property bool showSubtitle: true
    property int titlePx: 14
    signal activated()
    signal play()
    signal menu()
    width: size; height: showSubtitle ? size + 53 : size + 6 + 19
    Cover {
        width: t.size; height: t.size; rpx: 9; trackId: t.trackId; px: Math.round(t.size * 1.5)
        scale: ma.containsMouse ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Label { y: t.showSubtitle ? t.size + 8 : t.size + 6; width: t.size; elide: Text.ElideRight; text: t.title; font.pixelSize: t.titlePx; font.weight: Font.Medium }
    Label { visible: t.showSubtitle; y: t.size + 36; width: t.size; elide: Text.ElideRight; text: t.subtitle; font.pixelSize: 12; color: theme.muted }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
        onClicked: (m) => { if (m.button === Qt.RightButton) t.menu(); else t.activated() }
    }
    IconButton { x: t.size - 44; y: t.size - 44; size: 36; iconSize: 18; filled: true; icon: "play"; color: theme.onAccent; visible: ma.containsMouse; tip: qsTr("Play"); onClicked: t.play() }
}