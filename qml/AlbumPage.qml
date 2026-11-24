import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property var args: ({})                  // {album, albumArtist}
    property string query: ""
    readonly property var tf: { var f = Object.assign({}, args); if (query) f.text = query; return f }
    readonly property var info: albumInfo.total > 0 ? albumInfo.get(0) : ({})
    function dur(ms) { var s = Math.round(ms / 1000); return qsTr("%1 min %2 sec").arg(Math.floor(s / 60)).arg(s % 60) }

    LibraryModel { id: albumInfo; mode: "albums"; filters: v.args || ({}); limit: 1 }
    LibraryModel { id: lib; mode: "songs"; sort: "trackNo"; filters: v.tf }
    Timer { id: deb; interval: 200; onTriggered: v.query = head.query }
    TrackMenu { id: menu; app: v.app }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20
        PageHeading { id: head; Layout.fillWidth: true; title: v.info.title || ""; subtitle: qsTr("Library / Albums / %1").arg(v.info.title || ""); onQueryChanged: deb.restart() }
        TrackList {
            Layout.fillWidth: true; Layout.fillHeight: true
            lib: lib; useTrackNo: true; showColumns: true
            headerContent: Component {
                Row {
                    spacing: 28; bottomPadding: 20
                    Cover { width: 172; height: 172; rpx: 9; trackId: v.info.trackId || 0; px: 344 }
                    Column {
                        spacing: 10; anchors.verticalCenter: undefined
                        Label { text: qsTr("ALBUM") + (v.info.year > 0 ? " · " + v.info.year : ""); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.accent }
                        Label { width: 640; elide: Text.ElideRight; text: v.info.title || ""; font.pixelSize: 34; font.weight: Font.DemiBold }
                        Label { text: (v.info.artist || "") + " · " + qsTr("%1 songs").arg(v.info.count || 0) + " · " + v.dur(v.info.durationMs || 0); font.pixelSize: 13; color: theme.muted }
                        Row {
                            spacing: 12; topPadding: 4
                            ActionButton { primary: true; text: "▶  " + qsTr("Play album"); onClicked: pc.playTracks(lib.allIds()) }
                            ActionButton { text: qsTr("Shuffle"); onClicked: v.app.shufflePlay(lib.allIds()) }
                            ActionButton { text: qsTr("Add to queue"); onClicked: pc.enqueue(lib.allIds()) }
                            ActionButton { text: "···"; onClicked: { menu.ids = lib.allIds(); menu.single = 0; menu.popup() } }
                        }
                    }
                }
            }
        }
    }
}