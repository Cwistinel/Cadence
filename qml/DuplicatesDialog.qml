import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property var groups: []
    width: 680
    title: qsTr("Possible duplicates")
    primaryText: qsTr("Done")
    function show(tol) { groups = scanner.duplicates(tol); open() }
    Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.muted; font.pixelSize: 13
            text: d.groups.length === 0 ? qsTr("No duplicates found.") : qsTr("Review only. Cadence never deletes or changes your files.") }
    ListView {
        Layout.fillWidth: true; Layout.preferredHeight: 300; clip: true; spacing: 12; model: d.groups; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        delegate: Column {
            id: gr
            required property var modelData
            width: ListView.view ? ListView.view.width : 0; spacing: 3
            Label { text: gr.modelData.reason; font.pixelSize: 12; font.weight: Font.DemiBold; color: theme.accent }
            Repeater {
                model: gr.modelData.tracks
                Label { required property var modelData; width: gr.width; elide: Text.ElideMiddle; font.pixelSize: 12; text: modelData.artist + " — " + modelData.title + "   " + modelData.path }
            }
        }
    }
}
