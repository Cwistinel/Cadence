import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: pv
    readonly property var app: Window.window
    property int plId: 0
    property var rows: []
    property string name: ""
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    function refresh() {
        rows = playlists.items(plId)
        name = ""
        playlists.playlists.forEach(function (p) { if (p.id === plId) name = p.name })
    }
    function doExport(url, over) {
        var r = playlists.exportM3u(plId, url, over, false)
        if (r.ok) app.toast(qsTr("Exported %1 tracks").arg(r.written) + (r.skipped ? qsTr(" (%1 CUE tracks skipped)").arg(r.skipped) : ""))
        else if (r.error === "exists") app.confirm(qsTr("The file already exists. Overwrite it?"), function () { pv.doExport(url, true) })
        else app.toast(r.error)
    }
    onPlIdChanged: refresh()
    Component.onCompleted: refresh()
    Connections {
        target: playlists
        function onItemsChanged(id) { if (id === pv.plId) pv.refresh() }
        function onPlaylistsChanged() { pv.refresh() }
    }
    FileDialog {
        id: exp
        fileMode: FileDialog.SaveFile; defaultSuffix: "m3u8"; nameFilters: [qsTr("Playlists (*.m3u8 *.m3u)")]
        onAccepted: pv.doExport(selectedFile.toString(), false)
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        RowLayout {
            spacing: 8
            TextField { Layout.fillWidth: true; font.pixelSize: 18; text: pv.name; onEditingFinished: if (text.trim() !== "" && text !== pv.name) playlists.rename(pv.plId, text) }
            Button { text: qsTr("Play"); enabled: pv.rows.length > 0; onClicked: playlists.play(pv.plId) }
            Button { text: qsTr("Queue"); enabled: pv.rows.length > 0; onClicked: playlists.enqueue(pv.plId) }
            Button { text: qsTr("Export…"); onClicked: { exp.currentFile = "file:///" + pv.name + ".m3u8"; exp.open() } }
            Button { text: qsTr("Delete"); onClicked: pv.app.confirm(qsTr("Delete this playlist? Your music files are not touched."), function () { playlists.remove(pv.plId); pv.app.showPage("songs") }) }
        }
        Label { color: theme.subtext; font.pixelSize: 12; text: qsTr("%1 tracks. Drag ⋮⋮ to reorder; drop songs from the library to add them.").arg(pv.rows.length) }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: pv.rows
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                width: ListView.view.width; height: 52; radius: 6
                z: grip.Drag.active ? 5 : 0
                color: dz.containsDrag ? pv.alpha(theme.accent, 0.35) : "transparent"
                opacity: modelData.missing ? 0.45 : 1
                DropArea { id: dz; anchors.fill: parent; keys: ["pl"]; onDropped: (d) => playlists.move(pv.plId, d.source.srcIndex, row.index) }
                MouseArea { anchors.fill: parent; onDoubleClicked: playlists.play(pv.plId, row.index) }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 30; anchors.rightMargin: 6; spacing: 10
                    Cover { Layout.preferredWidth: 38; Layout.preferredHeight: 38; trackId: row.modelData.trackId; px: 80 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; text: row.modelData.title + (row.modelData.missing ? "  (" + qsTr("file missing") + ")" : "") }
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: theme.subtext; text: row.modelData.artist }
                    }
                    Label { text: pv.fmt(row.modelData.durationMs); font.pixelSize: 12; color: theme.subtext }
                    IconButton { size: 28; glyph: "✕"; color: theme.subtext; tip: qsTr("Remove from playlist"); onClicked: playlists.removeItems(pv.plId, [row.modelData.itemId]) }
                }
                Item {
                    id: grip
                    property int srcIndex: row.index
                    x: 2; y: 0; width: 26; height: row.height
                    Drag.active: gma.drag.active
                    Drag.keys: ["pl"]
                    Label { anchors.centerIn: parent; text: "⋮⋮"; color: theme.subtext }
                    MouseArea { id: gma; anchors.fill: parent; drag.target: grip; drag.axis: Drag.YAxis; onReleased: { grip.Drag.drop(); grip.x = 2; grip.y = 0 } }
                }
            }
        }
    }
    DropArea { anchors.fill: parent; keys: ["track"]; z: -1; onDropped: (d) => playlists.addTracks(pv.plId, d.source.ids()) }
}