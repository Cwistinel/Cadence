import QtQuick

Rectangle {
    id: t
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44; implicitHeight: 26; radius: 13
    color: checked ? theme.accent : theme.line
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
        y: 3; width: 20; height: 20; radius: 10; x: t.checked ? 21 : 3; color: t.checked ? theme.onAccent : theme.muted
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled(!t.checked) }
}
