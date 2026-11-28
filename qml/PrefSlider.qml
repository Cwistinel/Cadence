import QtQuick
import QtQuick.Controls

Item {
    id: p
    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property string label
    signal moved(real v)
    implicitWidth: 200; implicitHeight: 40
    opacity: enabled ? 1 : 0.4
    Label { anchors.right: parent.right; text: p.label; font.pixelSize: 12; color: theme.muted }
    Slider {
        id: sl
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 20; from: p.from; to: p.to; stepSize: p.stepSize
        Binding { target: sl; property: "value"; value: p.value; when: !sl.pressed }
        onMoved: p.moved(value)
        background: Rectangle {
            x: sl.leftPadding; y: sl.topPadding + sl.availableHeight / 2 - 3; width: sl.availableWidth; height: 6; radius: 3; color: theme.line
            Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 3; color: theme.accent }
        }
        handle: Rectangle { x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width); y: sl.topPadding + sl.availableHeight / 2 - height / 2; width: 14; height: 14; radius: 7; color: theme.accent }
    }
}
