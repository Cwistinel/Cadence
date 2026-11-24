import QtQuick

Rectangle {
    id: c
    property var trackId: 0
    property int px: 256
    property real corner: 0.14         // fraction of the side; 0.5 = circle
    property real rpx: -1              // corner radius in px (the design uses fixed radii); overrides `corner`
    readonly property real cf: Math.min(0.5, rpx >= 0 ? rpx / Math.max(1, Math.min(width, height)) : corner)
    color: theme.panel
    radius: Math.min(width, height) * cf
    Image {
        anchors.fill: parent
        source: c.trackId ? "image://art/" + c.trackId + "?r=" + c.cf.toFixed(3) : ""
        sourceSize.width: c.px; sourceSize.height: c.px
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }
}