import QtQuick

Rectangle {
    id: c
    property var trackId: 0
    property int px: 256
    property real corner: 0.14         // fraction of the side; 0.5 = circle
    color: theme.surface
    radius: Math.min(width, height) * corner
    Image {
        anchors.fill: parent
        source: c.trackId ? "image://art/" + c.trackId + "?r=" + c.corner : ""
        sourceSize.width: c.px; sourceSize.height: c.px
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }
}