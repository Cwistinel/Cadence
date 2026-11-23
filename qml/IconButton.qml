import QtQuick
import QtQuick.Controls

Item {
    id: b
    property string icon: ""
    property string glyph: ""
    property color color: theme.text
    property bool active: false
    property bool filled: false
    property bool tonal: false
    property real size: 40
    property string tip: ""
    signal clicked()
    implicitWidth: size; implicitHeight: size
    opacity: b.enabled ? 1 : 0.35
    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Rectangle {
        anchors.fill: parent; radius: width / 2
        color: b.filled ? theme.accent : b.tonal ? theme.text : b.color
        opacity: b.filled ? (ma.pressed ? 0.8 : 1)
               : Math.max(b.tonal ? 0.1 : 0, ma.pressed ? 0.25 : ma.containsMouse ? 0.16 : b.active ? 0.15 : 0)
        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }
    Icon { visible: b.icon !== ""; anchors.centerIn: parent; width: b.size * 0.55; height: width; name: b.icon; color: b.color }
    Label { visible: b.glyph !== ""; anchors.centerIn: parent; text: b.glyph; color: b.color; font.pixelSize: b.size * 0.5 }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true
        onClicked: b.clicked()
        ToolTip.visible: containsMouse && b.tip !== ""; ToolTip.text: b.tip; ToolTip.delay: 600
    }
}