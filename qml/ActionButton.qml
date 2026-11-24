import QtQuick
import QtQuick.Controls

// Figma "Action": 38 px high, 8 px radius. primary = accent fill; otherwise panel fill with a line border.
Rectangle {
    id: b
    property string text
    property bool primary: false
    signal clicked()
    implicitHeight: 38; implicitWidth: lbl.implicitWidth + 32
    radius: 8
    color: primary ? theme.accent : ma.containsMouse ? theme.tint : theme.panel
    border.width: primary ? 0 : 1; border.color: theme.line
    opacity: !enabled ? 0.45 : ma.pressed ? 0.85 : 1
    Behavior on color { ColorAnimation { duration: 140 } }
    Label { id: lbl; anchors.centerIn: parent; text: b.text; font.pixelSize: 13; font.weight: Font.Medium; color: b.primary ? theme.onAccent : theme.text }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}