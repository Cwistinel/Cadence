import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: r
    property string title
    property string description
    property bool first: false
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(50, tcol.implicitHeight + 16)
    Rectangle { visible: !r.first; width: parent.width; height: 1; color: theme.line }
    RowLayout {
        anchors.fill: parent; spacing: 16
        ColumnLayout {
            id: tcol
            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 3
            Label { Layout.fillWidth: true; elide: Text.ElideRight; text: r.title; font.pixelSize: 14; font.weight: Font.Medium }
            Label { visible: r.description !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: r.description; font.pixelSize: 12; color: theme.muted }
        }
        RowLayout { id: slot; Layout.alignment: Qt.AlignVCenter; spacing: 10 }
    }
}
