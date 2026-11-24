import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    LibraryModel { id: recent; mode: "albums"; sort: "played"; descending: true; filters: ({recentlyPlayed: true}); limit: 5 }
    LibraryModel { id: heroModel; mode: "albums"; filters: pc.hasTrack ? ({album: pc.track.album, albumArtist: pc.track.albumArtist}) : ({}); limit: 1 }
    readonly property var hero: pc.hasTrack && heroModel.total > 0 ? heroModel.get(0) : recent.total > 0 ? recent.get(0) : null
    function mins(ms) { return Math.max(1, Math.round(ms / 60000)) }

    Flickable {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21
        contentHeight: col.height + 24; clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Column {
            id: col
            width: parent.width; spacing: 20
            PageHeading { width: parent.width; title: qsTr("Home"); subtitle: qsTr("Your music. At your own pace."); onSubmitted: (t) => v.app.searchFor(t) }

            Rectangle {   // continue listening
                width: parent.width; height: 260; radius: 12; color: theme.panel
                RowLayout {
                    anchors.fill: parent; anchors.margins: 20; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 32
                    Cover { Layout.preferredWidth: 220; Layout.preferredHeight: 220; rpx: 9; trackId: v.hero ? v.hero.trackId : 0; px: 440 }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 15
                        Label { visible: v.hero !== null; text: qsTr("PICK UP WHERE YOU LEFT OFF"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.accent }
                        Label {
                            Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                            font.pixelSize: 32; font.weight: Font.DemiBold
                            text: v.hero ? v.hero.title : qsTr("No music yet.")
                        }
                        Label {
                            Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14; color: theme.muted
                            text: v.hero ? v.hero.artist + " · " + qsTr("%1 tracks").arg(v.hero.count) + " · " + qsTr("%1 min").arg(v.mins(v.hero.durationMs)) : qsTr("Add a folder in Settings, or drop one onto this window.")
                        }
                        RowLayout {
                            visible: v.hero !== null; spacing: 12
                            ActionButton { primary: true; text: "▶  " + qsTr("Resume listening"); onClicked: { if (pc.hasTrack) pc.play(); else pc.playTracks(recent.idsFor(0)) } }
                            ActionButton { text: qsTr("View album"); onClicked: v.app.openAlbum(v.hero.album, v.hero.albumArtist) }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width; visible: recent.total > 0; spacing: 12
                Label { Layout.fillWidth: true; text: qsTr("In your recent rotation"); font.pixelSize: 18; font.weight: Font.DemiBold }
                Label { text: qsTr("Recently played →"); font.pixelSize: 12; color: theme.accent
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: v.app.showPage("played") } }
            }
            Row {
                spacing: 24
                Repeater {
                    model: recent
                    delegate: Item {
                        required property int index
                        required property var trackId
                        required property string title
                        required property string album
                        required property string albumArtist
                        width: 196; height: 173
                        AlbumTile {
                            size: 148; trackId: parent.trackId; title: parent.title; showSubtitle: false; titlePx: 13
                            onActivated: v.app.openAlbum(parent.album, parent.albumArtist)
                            onPlay: pc.playTracks(recent.idsFor(parent.index))
                        }
                    }
                }
            }
        }
    }
}