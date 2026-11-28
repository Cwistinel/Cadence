import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property string dir: ""
    property string sel: ""
    property var folders: []
    title: qsTr("Choose a music folder")
    primaryText: qsTr("Add folder")
    primaryEnabled: sel !== ""
    function go(p) { dir = p; folders = scanner.listFolders(p); sel = p }
    function show() { go(scanner.homePath()); sel = scanner.musicPath(); open() }
    onAccepted: scanner.addFolder(sel)

    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Label { Layout.fillWidth: true; elide: Text.ElideMiddle; text: d.dir; font.pixelSize: 12; color: theme.muted }
        Label { visible: d.dir !== "/"; text: "↑ " + qsTr("Parent folder"); font.pixelSize: 12; color: theme.accent
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: d.go(d.dir.substring(0, d.dir.lastIndexOf("/")) || "/") } }
    }
    ListView {
        Layout.fillWidth: true; Layout.preferredHeight: 210; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        model: [{name: qsTr("This folder"), path: d.dir}].concat(d.folders)
        delegate: Rectangle {
            id: fr
            required property int index
            required property var modelData
            width: ListView.view ? ListView.view.width : 0; height: 40; radius: 6
            color: d.sel === modelData.path ? theme.tint : fma.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05) : "transparent"
            Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80; elide: Text.ElideRight; font.pixelSize: 14
                    color: d.sel === fr.modelData.path ? theme.accent : theme.text; text: (fr.index === 0 ? "• " : "▸ ") + fr.modelData.name }
            Label { visible: d.sel === fr.modelData.path; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Selected"); font.pixelSize: 11; color: theme.accent }
            MouseArea {
                id: fma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: d.sel = fr.modelData.path
                onDoubleClicked: if (fr.index > 0) d.go(fr.modelData.path)
            }
        }
    }
    Label { Layout.fillWidth: true; font.pixelSize: 12; color: scanner.isReadable(d.sel) ? theme.accent : theme.muted
            text: scanner.isReadable(d.sel) ? "✓  " + qsTr("Includes subfolders · Read access available") : qsTr("This folder can't be read") }
    Label { Layout.fillWidth: true; font.pixelSize: 11; color: theme.muted; text: qsTr("Click to select, double-click to open a folder.") }
}
