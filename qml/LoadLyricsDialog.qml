import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property var files: []
    property string picked: ""
    property string folder: ""
    signal browse()
    signal failed()
    title: qsTr("Load lyrics file")
    primaryText: qsTr("Load lyrics")
    primaryEnabled: picked !== ""
    function show() {
        files = lyrics.candidates()
        picked = files.length ? files[0].path : ""
        var p = pc.track.path || ""
        folder = p.substring(0, p.lastIndexOf("/"))
        open()
    }
    onAccepted: if (!lyrics.loadFile(picked)) failed()

    Label { Layout.fillWidth: true; elide: Text.ElideMiddle; text: d.folder; font.pixelSize: 12; color: theme.muted }
    Column {
        Layout.fillWidth: true; spacing: 6
        Repeater {
            model: d.files.slice(0, 6)
            delegate: Rectangle {
                id: fr
                required property var modelData
                width: parent.width; height: 38; radius: 6
                color: d.picked === modelData.path ? theme.tint : fma.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05) : "transparent"
                Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 52; elide: Text.ElideRight; font.pixelSize: 14; text: fr.modelData.name }
                Label { visible: d.picked === fr.modelData.path; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "✓"; font.pixelSize: 14; color: theme.accent }
                MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: d.picked = fr.modelData.path }
            }
        }
    }
    Label { visible: d.files.length === 0; Layout.fillWidth: true; text: qsTr("No .lrc or .txt files in this folder."); font.pixelSize: 13; color: theme.muted }
    RowLayout {
        Layout.fillWidth: true; spacing: 12
        Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: qsTr("LRC for synchronized lyrics · TXT for plain lyrics"); font.pixelSize: 12; color: theme.muted }
        Label { text: qsTr("Browse…"); font.pixelSize: 12; color: theme.accent
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { d.close(); d.browse() } } }
    }
}
