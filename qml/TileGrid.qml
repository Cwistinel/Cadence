import QtQuick
import QtQuick.Controls
import Cadence 1.0

// Grid of album / artist / folder (or song) tiles over a LibraryModel.
GridView {
    id: g
    readonly property var app: Window.window
    property var lib
    property string kind: "albums"                 // albums | artists | folders | songs
    property int tile: 192
    property int gap: 30
    property Component footerContent: null
    property string emptyText: ""
    signal folderOpened(string dir)

    clip: true; model: lib; boundsBehavior: Flickable.StopAtBounds
    cellWidth: tile + gap; cellHeight: tile + 53 + 28
    ScrollBar.vertical: ScrollBar {}
    onContentYChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()
    onCountChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()

    TrackMenu { id: ctx; app: g.app }

    footer: Column {
        width: g.width
        Item { width: parent.width; height: g.count === 0 && g.emptyText !== "" ? 140 : 0
            Label { anchors.centerIn: parent; visible: parent.height > 0; horizontalAlignment: Text.AlignHCenter; color: theme.muted; text: g.emptyText } }
        Loader { width: parent.width; sourceComponent: g.footerContent }
    }

    delegate: Item {
        id: cell
        required property int index
        required property var trackId
        required property string title
        required property string artist
        required property string album
        required property string albumArtist
        required property string folder
        required property int count
        required property int extra
        required property int year
        width: g.cellWidth; height: g.cellHeight
        AlbumTile {
            size: g.tile; trackId: cell.trackId; title: cell.title
            subtitle: g.kind === "albums" ? cell.artist + (cell.year > 0 ? " · " + cell.year : "")
                    : g.kind === "artists" ? (cell.extra === 1 ? qsTr("1 album") : qsTr("%1 albums").arg(cell.extra))
                    : g.kind === "folders" ? qsTr("%1 tracks").arg(cell.count) : cell.artist
            onActivated: {
                if (g.kind === "albums") g.app.openAlbum(cell.album, cell.albumArtist)
                else if (g.kind === "artists") g.app.openArtist(cell.artist)
                else if (g.kind === "folders") g.folderOpened(cell.folder)
                else pc.playTracks(g.lib.allIds(), cell.index)
            }
            onPlay: { if (g.kind === "songs") pc.playTracks(g.lib.allIds(), cell.index); else pc.playTracks(g.lib.idsFor(cell.index)) }
            onMenu: { ctx.ids = g.lib.idsFor(cell.index); ctx.single = g.kind === "songs" ? cell.trackId : 0; ctx.fav = false; ctx.popup() }
        }
    }
}