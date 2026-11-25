import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Figma dialog: 496 wide, 12 px radius, 24/28 padding, 22 px title with a × close, Cancel + accent action on the right.
Popup {
    id: d
    property string title
    property string primaryText: qsTr("OK")
    property bool primaryEnabled: true
    signal accepted()
    default property alias body: bodyCol.data
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: 496; padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 } }
    background: Rectangle { color: theme.panel; border.color: theme.line; border.width: 1; radius: 12 }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.45) }
    function accept() { if (!primaryEnabled) return; accepted(); close() }
    contentItem: ColumnLayout {
        spacing: 18
        RowLayout {
            Layout.fillWidth: true; Layout.topMargin: 24; Layout.leftMargin: 28; Layout.rightMargin: 28; spacing: 12
            Label { Layout.fillWidth: true; elide: Text.ElideRight; text: d.title; font.pixelSize: 22; font.weight: Font.DemiBold }
            Label { text: "×"; font.pixelSize: 22; color: theme.muted
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: d.close() } }
        }
        ColumnLayout { id: bodyCol; Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; spacing: 18 }
        RowLayout {
            Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.bottomMargin: 24; spacing: 12
            Item { Layout.fillWidth: true }
            ActionButton { implicitHeight: 40; text: qsTr("Cancel"); onClicked: d.close() }
            ActionButton { implicitHeight: 40; primary: true; enabled: d.primaryEnabled; text: d.primaryText; onClicked: d.accept() }
        }
    }
}