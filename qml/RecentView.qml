import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property string kind: "played"           // played | added
    property string query: ""
    readonly property bool added: kind === "added"

    function filters() { var f = added ? {recentlyAdded: true} : {recentlyPlayed: true}; if (query) f.text = query; return f }
    function sectionLabel(s) {
        if (!added) return s
        return s === qsTr("Today") ? qsTr("Added today") : s === qsTr("Yesterday") ? qsTr("Added yesterday") : qsTr("Added %1").arg(s)
    }

    LibraryModel { id: lib; mode: "songs"; sort: v.added ? "added" : "played"; descending: true; filters: v.filters() }
    LibraryModel { id: newest; mode: "albums"; sort: "added"; descending: true; limit: 4 }
    Timer { id: deb; interval: 200; onTriggered: v.query = head.query }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 16
        PageHeading {
            id: head; Layout.fillWidth: true
            title: v.added ? qsTr("Recently added") : qsTr("Recently played")
            subtitle: v.added ? qsTr("Fresh from your music folders") : qsTr("The sounds you keep coming back to")
            onQueryChanged: deb.restart()
        }
        TrackList {
            Layout.fillWidth: true; Layout.fillHeight: true
            lib: lib; sections: true; showColumns: !v.added
            sectionText: v.sectionLabel
            emptyText: v.added ? qsTr("Nothing new in the last 30 days.") : qsTr("Nothing played yet.")
            headerContent: v.added ? addedHeader : null
        }
    }

    Component {
        id: addedHeader
        Column {
            spacing: 16; bottomPadding: 20
            Rectangle {   // import status
                width: parent.width; height: 54; radius: 8; color: theme.panel; border.width: 0
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                    Label { text: "✓"; font.pixelSize: 20; color: theme.accent }
                    Label { Layout.fillWidth: true; text: scanner.lastScanText; font.pixelSize: 13; color: theme.muted }
                    ActionButton { text: scanner.scanning ? qsTr("Scanning…") : qsTr("Scan again"); enabled: !scanner.scanning && scanner.folders.length > 0; onClicked: scanner.rescanAll() }
                }
            }
            Row {
                spacing: 30
                Repeater {
                    model: newest
                    delegate: AlbumTile {
                        required property int index
                        required property var trackId
                        required property string title
                        required property string artist
                        required property string album
                        required property string albumArtist
                        required property int year
                        size: 192; subtitle: artist + (year > 0 ? " · " + year : "")
                        onActivated: v.app.openAlbum(album, albumArtist)
                        onPlay: pc.playTracks(newest.idsFor(index))
                    }
                }
            }
        }
    }
}