import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: c
    property string heading
    default property alias rows: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    radius: 10; color: theme.panel; border.width: 1; border.color: theme.line
    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 14
        spacing: 0
        Label { visible: c.heading !== ""; Layout.fillWidth: true; Layout.bottomMargin: 6; text: c.heading; font.pixelSize: 16; font.weight: Font.Medium }
    }
}
