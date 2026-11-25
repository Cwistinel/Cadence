import QtQuick
import QtQuick.Layouts

Item {
    property bool compact: false
    implicitHeight: 29
    RowLayout {
        x: 12; width: parent.width - 28; height: 28; spacing: 12
        Text { Layout.preferredWidth: 22; text: "#"; font.pixelSize: 11; color: theme.muted }
        Item { visible: !compact; Layout.preferredWidth: 36 }
        Text { Layout.fillWidth: true; Layout.preferredWidth: 300; text: qsTr("TITLE / ARTIST"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
        Text { Layout.fillWidth: true; Layout.preferredWidth: 521; text: qsTr("ALBUM"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
        Text { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: qsTr("TIME"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
        Item { Layout.preferredWidth: 77 }
    }
    Rectangle { y: 28; width: parent.width; height: 1; color: theme.line }
}