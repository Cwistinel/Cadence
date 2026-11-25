import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: v
    readonly property var app: Window.window
    property string query: ""
    readonly property var list: playlists.playlists.filter(function (p) { return !v.query || p.name.toLowerCase().indexOf(v.query.toLowerCase()) >= 0 })

    Timer { id: deb; interval: 150; onTriggered: v.query = head.query }
    StyledMenu {
        id: menu
        property var p: ({})
        StyledMenuItem { text: "▶  " + qsTr("Play now"); accentText: true; onTriggered: playlists.play(menu.p.id) }
        StyledMenuItem { text: qsTr("Add to queue"); onTriggered: playlists.enqueue(menu.p.id) }
        StyledMenuItem { text: qsTr("Rename"); onTriggered: v.app.renamePlaylist(menu.p.id) }
        StyledMenuItem { text: qsTr("Delete playlist"); onTriggered: v.app.deletePlaylist(menu.p.id) }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20
        PageHeading { id: head; Layout.fillWidth: true; routeToSearch: false; title: qsTr("Playlists"); subtitle: qsTr("Small collections for every kind of day"); onQueryChanged: deb.restart() }
        RowLayout {
            Layout.preferredHeight: 38; spacing: 12
            ActionButton { primary: true; text: "+  " + qsTr("Create playlist"); onClicked: v.app.askName(qsTr("New playlist"), "", function (n) { v.app.plId = playlists.create(n); v.app.showPage("playlist") }) }
            ActionButton { text: qsTr("Import .m3u"); onClicked: v.app.openImport() }
            Label { text: qsTr("Playlists are saved locally"); font.pixelSize: 12; color: theme.muted }
        }
        GridView {
            id: grid
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; boundsBehavior: Flickable.StopAtBounds
            cellWidth: 222; cellHeight: 273
            model: v.list
            ScrollBar.vertical: ScrollBar {}
            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                AlbumTile {
                    size: 192; trackId: cell.modelData.cover; title: cell.modelData.name
                    subtitle: qsTr("%1 tracks · Local playlist").arg(cell.modelData.count)
                    onActivated: { v.app.plId = cell.modelData.id; v.app.showPage("playlist") }
                    onPlay: playlists.play(cell.modelData.id)
                    onMenu: { menu.p = cell.modelData; menu.popup() }
                }
                DropArea { anchors.fill: parent; keys: ["track"]; onDropped: (d) => playlists.addTracks(cell.modelData.id, d.source.ids()) }
            }
            footer: Item {
                width: grid.width; height: 60
                Label { y: 6; font.pixelSize: 16; color: theme.muted; text: v.list.length === 0 && !v.query ? qsTr("No playlists yet. Create one to get started.") : qsTr("Made by you. Always available.") }
            }
        }
    }
}