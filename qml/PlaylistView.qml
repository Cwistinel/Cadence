import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: pv
    readonly property var app: Window.window
    property int plId: 0
    property var rows: []
    property string query: ""
    readonly property bool compact: (settings.revision, settings.text("ui/density", "comfortable") === "compact")
    readonly property var info: { var l = playlists.playlists; for (var i = 0; i < l.length; ++i) if (l[i].id === plId) return l[i]; return ({name: "", count: 0, cover: 0, durationMs: 0}) }
    readonly property var shown: {
        if (!query) return rows
        var q = query.toLowerCase()
        return rows.filter(function (r) { return (r.title + " " + r.artist + " " + r.album).toLowerCase().indexOf(q) >= 0 })
    }
    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    function total(ms) { var m = Math.round(ms / 60000); return m >= 60 ? qsTr("%1 hr %2 min").arg(Math.floor(m / 60)).arg(m % 60) : qsTr("%1 min").arg(m) }
    function refresh() { rows = playlists.items(plId) }
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
    Connections { target: pc; function onTrackUpdated() { pv.refresh() } }
    Timer { id: deb; interval: 150; onTriggered: pv.query = head.query }
    FileDialog {
        id: exp
        fileMode: FileDialog.SaveFile; defaultSuffix: "m3u8"; nameFilters: [qsTr("Playlists (*.m3u8 *.m3u)")]
        onAccepted: pv.doExport(selectedFile.toString(), false)
    }
    StyledMenu {
        id: more
        StyledMenuItem { text: qsTr("Add to queue"); onTriggered: playlists.enqueue(pv.plId) }
        StyledMenuItem { text: qsTr("Delete playlist"); onTriggered: pv.app.deletePlaylist(pv.plId) }
    }
    StyledMenu {
        id: rowMenu
        property var r: ({})
        StyledMenuItem { text: "▶  " + qsTr("Play now"); accentText: true; onTriggered: playlists.play(pv.plId, rowMenu.r.pos) }
        StyledMenuItem { text: qsTr("Play next"); onTriggered: pc.enqueue([rowMenu.r.trackId], true) }
        StyledMenuItem { text: qsTr("Add to queue"); onTriggered: pc.enqueue([rowMenu.r.trackId]) }
        StyledMenuItem { text: rowMenu.r.favorite ? "♥  " + qsTr("Remove from favorites") : "♡  " + qsTr("Add to favorites"); onTriggered: pc.setFavorite(rowMenu.r.trackId, !rowMenu.r.favorite) }
        StyledMenuItem { text: qsTr("Remove from playlist"); onTriggered: playlists.removeItems(pv.plId, [rowMenu.r.itemId]) }
        StyledMenuItem { text: qsTr("Edit track details"); onTriggered: pv.app.openMeta(rowMenu.r.trackId) }
        StyledMenuItem { text: qsTr("Show in folder"); onTriggered: scanner.showInFolder(rowMenu.r.trackId) }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20
        PageHeading { id: head; Layout.fillWidth: true; routeToSearch: false; title: pv.info.name; subtitle: qsTr("Playlists / %1").arg(pv.info.name); onQueryChanged: deb.restart() }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: pv.shown; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            header: Column {
                width: list.width; spacing: 20
                Row {
                    spacing: 28
                    Cover { width: 150; height: 150; rpx: 9; trackId: pv.info.cover; px: 300 }
                    Column {
                        spacing: 10
                        Label { text: qsTr("YOUR PLAYLIST"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.accent }
                        Label { width: 640; elide: Text.ElideRight; text: pv.info.name; font.pixelSize: 30; font.weight: Font.DemiBold }
                        Label { text: qsTr("%1 songs").arg(pv.info.count) + " · " + pv.total(pv.info.durationMs); font.pixelSize: 13; color: theme.muted }
                        Row {
                            spacing: 12; topPadding: 4
                            ActionButton { primary: true; text: "▶  " + qsTr("Play"); enabled: pv.rows.length > 0; onClicked: playlists.play(pv.plId) }
                            ActionButton { text: qsTr("Shuffle"); enabled: pv.rows.length > 0; onClicked: pv.app.shufflePlay(pv.rows.map(function (r) { return r.trackId })) }
                            ActionButton { text: "+ " + qsTr("Add songs"); onClicked: pv.app.addSongs(pv.plId) }
                            ActionButton { text: qsTr("Rename"); onClicked: pv.app.renamePlaylist(pv.plId) }
                            ActionButton { text: qsTr("Export"); onClicked: { exp.currentFile = "file:///" + pv.info.name + ".m3u8"; exp.open() } }
                            ActionButton { text: "···"; onClicked: more.popup() }
                        }
                    }
                }
                TrackColumns { width: parent.width; compact: pv.compact }
            }
            footer: Item {
                width: list.width; height: pv.rows.length === 0 ? 140 : 0
                Label { anchors.centerIn: parent; visible: parent.height > 0; horizontalAlignment: Text.AlignHCenter; color: theme.muted
                        text: qsTr("This playlist is empty.\nUse “Add songs”, or drop songs from the library here.") }
            }
            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property bool cur: pc.track.id === modelData.trackId
                width: ListView.view ? ListView.view.width : 0
                height: pv.compact ? 40 : 53
                radius: 7
                opacity: modelData.missing ? 0.45 : 1
                z: grip.Drag.active ? 5 : 0
                color: dz.containsDrag ? pv.a(theme.accent, 0.3) : cur ? theme.tint : ma.containsMouse ? pv.a(theme.text, 0.04) : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
                DropArea { id: dz; anchors.fill: parent; keys: ["pl"]; onDropped: (d) => playlists.move(pv.plId, d.source.srcPos, row.modelData.pos) }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => { if (m.button === Qt.RightButton) { rowMenu.r = row.modelData; rowMenu.popup() } }
                    onDoubleClicked: playlists.play(pv.plId, row.modelData.pos)
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 12
                    Label { Layout.preferredWidth: 22; font.pixelSize: 12; color: row.cur ? theme.accent : theme.muted
                            text: row.cur ? (pc.playing ? "Ⅱ" : "▶") : (row.modelData.pos + 1 < 10 ? "0" + (row.modelData.pos + 1) : row.modelData.pos + 1) }
                    Cover { visible: !pv.compact; Layout.preferredWidth: 36; Layout.preferredHeight: 36; rpx: 9; trackId: row.modelData.trackId; px: 96 }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 300; spacing: 0
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; color: row.cur ? theme.accent : theme.text
                                text: row.modelData.title + (row.modelData.missing ? "  (" + qsTr("file missing") + ")" : "") }
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: theme.muted; text: row.modelData.artist }
                    }
                    Label { Layout.fillWidth: true; Layout.preferredWidth: 521; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted; text: row.modelData.album }
                    Label { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 12; color: theme.muted; text: pv.fmt(row.modelData.durationMs) }
                    Label {
                        Layout.leftMargin: 14; text: row.modelData.favorite ? "♥" : "♡"; font.pixelSize: 19; color: row.modelData.favorite ? theme.accent : theme.muted
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: pc.setFavorite(row.modelData.trackId, !row.modelData.favorite) }
                    }
                    Label {
                        Layout.leftMargin: 14; text: "···"; font.pixelSize: 20; color: theme.muted
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { rowMenu.r = row.modelData; rowMenu.popup() } }
                    }
                }
                Item {   // drag handle over the number column: reorder within the playlist
                    id: grip
                    property int srcPos: row.modelData.pos
                    x: 0; y: 0; width: 34; height: row.height
                    Drag.active: gma.drag.active
                    Drag.keys: ["pl"]
                    MouseArea {
                        id: gma; anchors.fill: parent; drag.target: grip; drag.axis: Drag.YAxis; cursorShape: Qt.OpenHandCursor
                        onDoubleClicked: playlists.play(pv.plId, row.modelData.pos)
                        onReleased: { grip.Drag.drop(); grip.x = 0; grip.y = 0 }
                    }
                }
            }
        }
    }
    DropArea { anchors.fill: parent; keys: ["track"]; z: -1; onDropped: (d) => playlists.addTracks(pv.plId, d.source.ids()) }
}