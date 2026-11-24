import QtQuick
import QtQuick.Controls

MenuItem {
    id: mi
    property bool accentText: false
    implicitHeight: 36; implicitWidth: 234
    leftPadding: 12; rightPadding: 12
    contentItem: Label { text: mi.text; font.pixelSize: 13; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; color: mi.accentText || mi.highlighted ? theme.accent : theme.text }
    background: Rectangle { radius: 6; color: mi.highlighted ? theme.tint : "transparent" }
}