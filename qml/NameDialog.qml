import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property string mode: "create"          // create | rename
    property int count: 0
    property var cb
    title: mode === "create" ? qsTr("Create playlist") : qsTr("Rename playlist")
    primaryText: mode === "create" ? qsTr("Create playlist") : qsTr("Save name")
    primaryEnabled: field.text.trim() !== ""
    function show(initial) { field.text = initial; open() }
    onOpened: field.focusInput()
    onAccepted: if (cb && field.text.trim() !== "") cb(field.text.trim())
    Label { visible: d.mode === "create"; Layout.fillWidth: true; text: qsTr("Give your collection a name."); font.pixelSize: 13; color: theme.muted }
    Label { text: qsTr("Playlist name"); font.pixelSize: 12; color: theme.muted }
    DialogField { id: field; Layout.fillWidth: true; onAccepted: d.accept() }
    Label {
        Layout.fillWidth: true; font.pixelSize: 12; color: theme.muted
        text: d.mode === "create" ? qsTr("Saved locally on this device.") : d.count > 0 ? qsTr("%1 tracks will stay in this playlist.").arg(d.count) : ""
    }
}