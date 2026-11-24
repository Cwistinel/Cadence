import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property string sortKey: "title"
    property bool desc: false
    property string query: ""
    readonly property var sortOpts: [{v: "title", t: qsTr("Title")}, {v: "artist", t: qsTr("Artist")}, {v: "album", t: qsTr("Album")}, {v: "duration", t: qsTr("Length")},
                                     {v: "added", t: qsTr("Date added")}, {v: "plays", t: qsTr("Play count")}]
    readonly property string sortLabel: { for (var i = 0; i < sortOpts.length; ++i) if (sortOpts[i].v === sortKey) return sortOpts[i].t; return "" }

    LibraryModel { id: lib; mode: "songs"; sort: v.sortKey; descending: v.desc; filters: v.query ? ({favorite: true, text: v.query}) : ({favorite: true}) }
    Timer { id: deb; interval: 200; onTriggered: v.query = head.query }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20
        PageHeading { id: head; Layout.fillWidth: true; title: qsTr("Favorites"); subtitle: qsTr("%1 tracks worth keeping close").arg(lib.total); onQueryChanged: deb.restart() }
        TrackList {
            Layout.fillWidth: true; Layout.fillHeight: true
            lib: lib; showColumns: true
            emptyText: qsTr("No favorites yet.\nTap the heart on a track to keep it close.")
            headerContent: Component {
                Row {
                    height: 58; spacing: 12
                    ActionButton { primary: true; text: "▶  " + qsTr("Play favorites"); enabled: lib.total > 0; onClicked: pc.playTracks(lib.allIds()) }
                    ActionButton { text: qsTr("Shuffle"); enabled: lib.total > 0; onClicked: v.app.shufflePlay(lib.allIds()) }
                    DropButton {
                        text: qsTr("Sort: %1").arg(v.sortLabel) + " ⌄"; options: v.sortOpts
                        onPicked: (val) => { if (val === v.sortKey) v.desc = !v.desc; else { v.sortKey = val; v.desc = val === "added" || val === "plays" } }
                    }
                }
            }
        }
    }
}