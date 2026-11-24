import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

ListView {
    id: g
    readonly property var app: Window.window
    property var lib
    property string kind: "albums"
    property string emptyText: ""
    signal folderOpened(string dir)
    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    clip: true; model: lib; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    onContentYChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()
    onCountChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()
    footer: Item {
        width: g.width; height: g.count === 0 && g.emptyText !== "" ? 140 : 0
        Label { anchors.centerIn: parent; visible: parent.height > 0; horizontalAlignment: Text.AlignHCenter; color: theme.muted; text: g.emptyText }
    }
    delegate: Rectangle {
        id: row
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
        width: ListView.view ? ListView.view.width : 0; height: 64; radius: 7
        color: ma.containsMouse ? g.a(theme.text, 0.05) : "transparent"
        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (g.kind === "albums") g.app.openAlbum(row.album, row.albumArtist)
                else if (g.kind === "artists") g.app.openArtist(row.artist)
                else g.folderOpened(row.folder)
            }
        }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 14
            Cover { Layout.preferredWidth: 48; Layout.preferredHeight: 48; rpx: 9; trackId: row.trackId; px: 96 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; text: row.title || qsTr("(Unknown)") }
                Label {
                    Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted
                    text: g.kind === "albums" ? row.artist + (row.year > 0 ? " · " + row.year : "") + " · " + qsTr("%1 songs").arg(row.count)
                        : g.kind === "artists" ? qsTr("%1 albums").arg(row.extra) + " · " + qsTr("%1 songs").arg(row.count) : row.folder
                }
            }
            IconButton { size: 32; iconSize: 18; icon: "play"; color: theme.accent; tip: qsTr("Play"); onClicked: pc.playTracks(g.lib.idsFor(row.index)) }
        }
    }
}