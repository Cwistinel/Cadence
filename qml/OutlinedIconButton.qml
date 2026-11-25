import QtQuick
import QtQuick.Controls

Rectangle {
    id: b
    property string icon
    property color iconColor: theme.text
    property real iconSize: 20
    property string tip: ""
    property string badge: ""
    signal clicked()
    implicitWidth: 46; implicitHeight: 38
    radius: 8
    color: ma.containsMouse ? theme.tint : theme.panel
    border.width: 1; border.color: theme.line
    opacity: !enabled ? 0.4 : ma.pressed ? 0.85 : 1
    Behavior on color { ColorAnimation { duration: 140 } }
    Icon { anchors.centerIn: parent; width: b.iconSize; height: width; name: b.icon; color: b.iconColor }
    Label { visible: b.badge !== ""; anchors.right: parent.right; anchors.rightMargin: 7; anchors.top: parent.top; anchors.topMargin: 3; text: b.badge; font.pixelSize: 9; font.weight: Font.DemiBold; color: b.iconColor }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
        ToolTip.visible: containsMouse && b.tip !== ""; ToolTip.text: b.tip; ToolTip.delay: 600
    }
}
