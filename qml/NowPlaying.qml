import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: np
    readonly property var app: Window.window
    readonly property real art: Math.max(180, Math.min(370, np.height - 60 - 24 - 21 - 20 - 36 - 12))
    function fmt(ms) { var t = Math.max(0, Math.floor(ms / 1000)); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }

    StyledMenu {
        id: more
        StyledMenuItem { text: pc.track.favorite ? "♥  " + qsTr("Remove from favorites") : "♡  " + qsTr("Add to favorites"); onTriggered: pc.toggleFavorite() }
        StyledMenu {
            id: pls
            title: qsTr("Add to playlist") + "  ›"
            StyledMenuItem { text: qsTr("New playlist…"); onTriggered: np.app.askName(qsTr("New playlist"), "", function (n) { playlists.addTracks(playlists.create(n), [pc.track.id]) }) }
            Instantiator {
                model: playlists.playlists
                delegate: StyledMenuItem { required property var modelData; text: modelData.name; onTriggered: playlists.addTracks(modelData.id, [pc.track.id]) }
                onObjectAdded: (i, o) => pls.insertItem(i + 1, o)
                onObjectRemoved: (i, o) => pls.removeItem(o)
            }
        }
        StyledMenuItem { text: qsTr("Edit track details"); onTriggered: np.app.openMeta(pc.track.id) }
        StyledMenuItem { text: qsTr("Edit lyrics…"); onTriggered: np.app.editLyrics() }
        StyledMenuItem { text: qsTr("Show in folder"); onTriggered: scanner.showInFolder(pc.track.id) }
    }
    Popup {
        id: volPop
        parent: volBtn
        x: (volBtn.width - width) / 2; y: -height - 8
        width: 230; padding: 14
        background: Rectangle { color: theme.panel; border.color: theme.line; radius: 10 }
        contentItem: RowLayout {
            spacing: 10
            IconButton { size: 28; iconSize: 20; icon: pc.muted || pc.volume === 0 ? "muted" : "volume"; color: theme.muted; tip: qsTr("Mute"); onClicked: pc.muted = !pc.muted }
            ThemedSlider { Layout.fillWidth: true; from: 0; to: 1; bound: pc.volume; onMoved: { pc.muted = false; pc.volume = value } }
        }
    }

    Flickable {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21
        contentWidth: width; contentHeight: col.height + 24
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Column {
            id: col
            width: parent.width; spacing: 24

            RowLayout {   // page header
                width: parent.width; height: 60; spacing: 12
                Label { Layout.fillWidth: true; text: qsTr("Now playing"); font.pixelSize: 28; font.weight: Font.DemiBold }
                ActionButton { text: qsTr("Queue"); textColor: np.app.rightPanel ? theme.accent : theme.text; onClicked: np.app.rightPanel = !np.app.rightPanel }
                ActionButton { text: qsTr("Lyrics"); onClicked: np.app.showPage("lyrics") }
                ActionButton { text: "···"; onClicked: more.popup() }
            }

            RowLayout {   // artwork + information
                x: 24; width: parent.width - 24; spacing: 64

                Column {
                    Layout.alignment: Qt.AlignTop; spacing: 12
                    Cover { width: np.art; height: np.art; rpx: 9; trackId: pc.track.id || 0; px: 740 }
                    Label { visible: pc.hasTrack; font.pixelSize: 11; color: theme.muted; text: scanner.formatInfo(pc.track.id || 0) + (scanner.formatInfo(pc.track.id || 0) ? " · " : "") + qsTr("Local file") }
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.maximumWidth: 580; Layout.alignment: Qt.AlignTop; spacing: 14

                    Label { visible: pc.hasTrack; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.accent
                            text: qsTr("FROM YOUR LIBRARY") + (pc.track.album ? " / " + pc.track.album.toUpperCase() : "") }
                    Label { Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: 44; font.weight: Font.DemiBold
                            text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing") }
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 21; color: theme.muted; text: pc.hasTrack ? pc.track.artist : "" }
                    Label { visible: pc.hasTrack && pc.track.album !== ""; font.pixelSize: 13; color: theme.muted; text: pc.track.album + (pc.track.year > 0 ? " · " + pc.track.year : "") }

                    ColumnLayout {   // seek controls
                        Layout.fillWidth: true; Layout.topMargin: 12; spacing: 4
                        WavySeekbar {
                            id: bar
                            Layout.fillWidth: true; Layout.preferredHeight: 25
                            enabled: pc.hasTrack
                            position: pc.position; duration: pc.duration; playing: pc.playing
                            accent: theme.accent; trackColor: theme.muted; thumbColor: theme.text
                            onSeekRequested: (ms) => pc.seek(ms)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Label { font.pixelSize: 12; color: theme.muted; text: np.fmt(bar.scrubbing ? bar.scrubPosition : pc.position) }
                            Item { Layout.fillWidth: true }
                            Label { font.pixelSize: 12; color: theme.muted; text: np.fmt(pc.duration) }
                        }
                    }

                    RowLayout {   // main transport
                        Layout.alignment: Qt.AlignHCenter; spacing: 22
                        OutlinedIconButton { Layout.alignment: Qt.AlignVCenter; implicitWidth: 46; icon: "shuffle"; iconColor: pc.shuffle ? theme.accent : theme.text; tip: qsTr("Shuffle"); onClicked: pc.shuffle = !pc.shuffle }
                        OutlinedIconButton { Layout.alignment: Qt.AlignVCenter; implicitWidth: 50; icon: "prev"; iconSize: 19; enabled: pc.canPrevious; tip: qsTr("Previous"); onClicked: pc.previous() }
                        Item {
                            id: big
                            Layout.preferredWidth: 64; Layout.preferredHeight: 64
                            Rectangle {
                                anchors.fill: parent; radius: 32; color: theme.accent
                                opacity: bma.pressed ? 0.85 : 1
                                scale: bma.pressed ? 0.95 : 1
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            Icon { anchors.centerIn: parent; width: 28; height: 28; name: pc.playing ? "pause" : "play"; color: theme.onAccent }
                            MouseArea {
                                id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pc.togglePlayPause()
                                ToolTip.visible: containsMouse; ToolTip.text: qsTr("Play / Pause"); ToolTip.delay: 600
                            }
                        }
                        OutlinedIconButton { Layout.alignment: Qt.AlignVCenter; implicitWidth: 50; icon: "next"; iconSize: 19; enabled: pc.canNext; tip: qsTr("Next"); onClicked: pc.next() }
                        OutlinedIconButton { Layout.alignment: Qt.AlignVCenter; implicitWidth: 46; icon: "repeat"; iconColor: pc.repeat > 0 ? theme.accent : theme.text; badge: pc.repeat === 2 ? "1" : ""; tip: pc.repeat === 2 ? qsTr("Repeat one") : qsTr("Repeat"); onClicked: pc.repeat = (pc.repeat + 1) % 3 }
                    }

                    RowLayout {   // secondary controls
                        Layout.alignment: Qt.AlignHCenter; spacing: 12
                        ActionButton { enabled: pc.hasTrack; text: pc.track.favorite ? "♥  " + qsTr("Favorited") : "♡  " + qsTr("Favorite"); textColor: pc.track.favorite ? theme.accent : theme.text; onClicked: pc.toggleFavorite() }
                        ActionButton { id: volBtn; text: qsTr("Volume %1%").arg(pc.muted ? 0 : Math.round(pc.volume * 100)); onClicked: volPop.open() }
                        ActionButton { text: qsTr("Mini-player"); onClicked: np.app.miniMode = true }
                    }
                }
            }
        }
    }
}
