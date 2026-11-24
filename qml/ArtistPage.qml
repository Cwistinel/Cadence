import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property var args: ({})                  // {artist}
    property string query: ""
    readonly property var tf: { var f = Object.assign({}, args); if (query) f.text = query; return f }
    readonly property var info: artistInfo.total > 0 ? artistInfo.get(0) : ({})
    readonly property string genres: lib.distinctWhere("genre", args || ({})).slice(0, 3).join(" / ")

    LibraryModel { id: artistInfo; mode: "artists"; filters: v.args || ({}); limit: 1 }
    LibraryModel { id: albums; mode: "albums"; sort: "added"; descending: true; filters: v.args || ({}) }
    LibraryModel { id: lib; mode: "songs"; sort: "album"; filters: v.tf }
    Timer { id: deb; interval: 200; onTriggered: v.query = head.query }
    TrackMenu { id: menu; app: v.app }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 16
        PageHeading {
            id: head; Layout.fillWidth: true
            title: v.info.title || ""
            subtitle: qsTr("Artist · %1 albums · %2 songs").arg(v.info.extra || 0).arg(v.info.count || 0)
            onQueryChanged: deb.restart()
        }
        TrackList {
            Layout.fillWidth: true; Layout.fillHeight: true
            lib: lib; showColumns: false
            headerContent: Component {
                Column {
                    spacing: 16; bottomPadding: 16
                    Row {
                        spacing: 28
                        Cover { width: 150; height: 150; rpx: 9; trackId: v.info.trackId || 0; px: 300 }
                        Column {
                            spacing: 14; topPadding: 28
                            Label { visible: v.genres !== ""; text: v.genres; font.pixelSize: 13; color: theme.muted }
                            Row {
                                spacing: 12
                                ActionButton { primary: true; text: "▶  " + qsTr("Play artist"); onClicked: pc.playTracks(lib.allIds()) }
                                ActionButton { text: qsTr("Shuffle"); onClicked: v.app.shufflePlay(lib.allIds()) }
                                ActionButton { text: "···"; onClicked: { menu.ids = lib.allIds(); menu.single = 0; menu.popup() } }
                            }
                        }
                    }
                    Label { visible: albums.total > 0; text: qsTr("Albums"); font.pixelSize: 18; font.weight: Font.DemiBold }
                    ListView {
                        visible: albums.total > 0
                        width: parent.width; height: 221; orientation: ListView.Horizontal; spacing: 26; clip: true; model: albums
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: AlbumTile {
                            required property int index
                            required property var trackId
                            required property string title
                            required property string artist
                            required property string album
                            required property string albumArtist
                            required property int year
                            size: 168; subtitle: artist + (year > 0 ? " · " + year : "")
                            onActivated: v.app.openAlbum(album, albumArtist)
                            onPlay: pc.playTracks(albums.idsFor(index))
                        }
                    }
                }
            }
        }
    }
}