import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property string kind: "albums"           // songs | albums | artists | folders
    property var drill: null                 // folder drill-down
    property var uf: ({})                    // advanced filters
    property string genre: ""
    property string query: ""
    property string sortKey: "added"
    property bool desc: true
    readonly property string mode: drill ? "songs" : ({albums: "albums", artists: "artists", folders: "folders"})[kind] || "songs"
    readonly property string viewKey: drill ? "songs" : kind
    readonly property bool grid: (settings.revision, settings.text("ui/view/" + viewKey, viewKey === "albums" || viewKey === "artists" ? "grid" : "list") === "grid")
    readonly property var sortOpts: mode === "songs"
        ? [{v: "added", t: qsTr("Recently added")}, {v: "title", t: qsTr("Title")}, {v: "artist", t: qsTr("Artist")}, {v: "album", t: qsTr("Album")}, {v: "trackNo", t: qsTr("Track no.")},
           {v: "duration", t: qsTr("Length")}, {v: "played", t: qsTr("Last played")}, {v: "plays", t: qsTr("Play count")}]
        : [{v: "added", t: qsTr("Recently added")}, {v: "title", t: qsTr("Name")}, {v: "count", t: qsTr("Tracks")}, {v: "played", t: qsTr("Last played")}]
    readonly property string sortLabel: { for (var i = 0; i < sortOpts.length; ++i) if (sortOpts[i].v === sortKey) return sortOpts[i].t; return "" }
    readonly property var st: scanner.stats

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function resetSort() { sortKey = kind === "folders" ? "title" : "added"; desc = kind !== "folders" }
    function setF(k, val) { var o = Object.assign({}, uf); if (!val) delete o[k]; else o[k] = val; uf = o }
    function buildFilters() {
        var f = Object.assign({}, uf)
        if (query) f.text = query
        if (genre) f.genre = genre
        if (drill) f = Object.assign(f, drill)
        return f
    }
    function genreOptions() {
        var o = [{v: "", t: qsTr("All genres")}]
        mainModel.distinct("genre").forEach(function (g) { o.push({v: g, t: g}) })
        o.push({v: "::more", t: qsTr("More filters…")})
        return o
    }
    onKindChanged: { drill = null; uf = ({}); genre = ""; resetSort() }
    Component.onCompleted: { resetSort(); if (app.pendingQuery !== "") { head.setQuery(app.pendingQuery); app.pendingQuery = "" } }

    LibraryModel { id: mainModel; mode: v.mode; sort: v.sortKey; descending: v.desc; filters: v.buildFilters() }
    LibraryModel { id: recent; mode: "songs"; sort: "added"; descending: true; limit: 5 }
    LibraryModel { id: allArtists; mode: "artists"; sort: "title" }
    Connections { target: allArtists; function onRowsInserted() { allArtists.loadMore() } }
    Timer { id: deb; interval: 200; onTriggered: v.query = head.query }
    TrackMenu { id: recentMenu; app: v.app }

    component TabChip: Rectangle {
        id: tc
        property string label
        property bool on: false
        signal clicked()
        implicitHeight: 34; implicitWidth: tl.implicitWidth + 28; radius: 6
        color: on ? theme.tint : tma.containsMouse ? v.a(theme.text, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
        Label { id: tl; anchors.centerIn: parent; text: tc.label; font.pixelSize: 13; font.weight: Font.Medium; color: tc.on ? theme.accent : theme.muted }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tc.clicked() }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 16

        PageHeading {
            id: head
            Layout.fillWidth: true
            title: v.drill ? mainModel.total >= 0 ? v.drill.folder.split("/").pop() : "" : v.kind === "songs" ? qsTr("Library · Songs") : v.kind === "albums" ? qsTr("Library") : v.kind === "artists" ? qsTr("Artists") : qsTr("Library · Folders")
            subtitle: v.drill ? qsTr("%1 songs").arg(mainModel.total)
                    : v.kind === "songs" ? qsTr("%1 songs · Stored on this device").arg(v.st.songs || 0)
                    : v.kind === "albums" ? qsTr("%1 songs · %2 albums · %3 artists").arg(v.st.songs || 0).arg(v.st.albums || 0).arg(v.st.artists || 0)
                    : v.kind === "artists" ? qsTr("%1 artists in your local library").arg(v.st.artists || 0) : qsTr("%1 folders").arg(mainModel.total)
            onQueryChanged: deb.restart()
        }

        RowLayout {   // toolbar
            Layout.fillWidth: true; Layout.preferredHeight: 38; spacing: 12
            ActionButton { visible: v.drill !== null; text: "←  " + qsTr("Back"); onClicked: v.drill = null }
            Row {
                spacing: 12
                Repeater {
                    model: [{k: "songs", t: qsTr("Songs")}, {k: "albums", t: qsTr("Albums")}, {k: "artists", t: qsTr("Artists")}, {k: "folders", t: qsTr("Folders")}]
                    delegate: TabChip { required property var modelData; label: modelData.t; on: v.kind === modelData.k; onClicked: v.app.page = modelData.k }
                }
            }
            Item { Layout.fillWidth: true }
            DropButton {
                text: (v.genre || qsTr("All genres")) + " ⌄"
                onAboutToOpen: options = v.genreOptions()
                onPicked: (val) => { if (val === "::more") fp.open(); else v.genre = val }
            }
            DropButton {
                text: v.sortLabel + " ⌄"
                options: v.sortOpts
                onPicked: (val) => { if (val === v.sortKey) v.desc = !v.desc; else { v.sortKey = val; v.desc = val === "added" || val === "played" || val === "plays" } }
            }
            Rectangle {   // grid / list switch
                Layout.preferredWidth: 64; Layout.preferredHeight: 38; radius: 8; color: theme.panel; border.width: 1; border.color: theme.line
                Row {
                    anchors.centerIn: parent; spacing: 12
                    Label { text: "▦"; font.pixelSize: 15; color: v.grid ? theme.accent : theme.text
                        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: settings.setValue("ui/view/" + v.viewKey, "grid") } }
                    Label { text: "☷"; font.pixelSize: 15; color: !v.grid ? theme.accent : theme.text
                        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: settings.setValue("ui/view/" + v.viewKey, "list") } }
                }
            }
        }

        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            sourceComponent: v.mode === "songs" && !v.grid ? songsComp : v.grid ? tilesComp : groupsComp
        }
    }

    readonly property string emptyText: scanner.folders.length === 0 ? qsTr("No music yet.\nAdd a folder in Settings, or drop one onto this window.") : qsTr("Nothing matches.")

    Component {
        id: songsComp
        TrackList {
            lib: mainModel; showColumns: true; emptyText: v.emptyText
            headerContent: Component {
                Row {
                    height: 54; spacing: 12
                    ActionButton { primary: true; text: "▶  " + qsTr("Play all"); enabled: mainModel.total > 0; onClicked: pc.playTracks(mainModel.allIds()) }
                    ActionButton { text: qsTr("Shuffle"); enabled: mainModel.total > 0; onClicked: v.app.shufflePlay(mainModel.allIds()) }
                    Label { anchors.verticalCenter: undefined; y: 10; text: qsTr("All tracks are available offline"); font.pixelSize: 12; color: theme.muted }
                }
            }
        }
    }
    Component {
        id: tilesComp
        TileGrid {
            lib: mainModel; kind: v.mode; emptyText: v.emptyText
            onFolderOpened: (d) => v.drill = {folder: d}
            footerContent: v.mode === "albums" ? albumsFooter : v.mode === "artists" ? artistsFooter : null
        }
    }
    Component {
        id: groupsComp
        GroupList { lib: mainModel; kind: v.mode; emptyText: v.emptyText; onFolderOpened: (d) => v.drill = {folder: d} }
    }

    Component {
        id: albumsFooter
        Column {
            width: parent ? parent.width : 0; spacing: 12; topPadding: 6
            RowLayout {
                width: parent.width; spacing: 12
                Label { Layout.fillWidth: true; text: qsTr("Recently added tracks"); font.pixelSize: 18; font.weight: Font.DemiBold }
                Label { text: qsTr("View all →"); font.pixelSize: 12; color: theme.accent
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: v.app.showPage("added") } }
            }
            Repeater {
                model: recent
                delegate: TrackRow {
                    width: parent.width
                    playing: pc.track.id === trackId
                    onPlayRequested: pc.playTracks(recent.allIds(), index)
                    onFavoriteToggled: pc.setFavorite(trackId, !favorite)
                    onMenuRequested: { recentMenu.ids = [trackId]; recentMenu.single = trackId; recentMenu.fav = favorite; recentMenu.popup() }
                }
            }
        }
    }
    Component {
        id: artistsFooter
        Column {
            width: parent ? parent.width : 0; spacing: 20; topPadding: 6; bottomPadding: 20
            Label { text: qsTr("All artists  /  A–Z"); font.pixelSize: 16; font.weight: Font.Medium }
            Flow {
                width: parent.width; spacing: 48
                Repeater {
                    model: allArtists
                    delegate: Label {
                        required property string artist
                        text: artist; font.pixelSize: 14; color: am.containsMouse ? theme.accent : theme.text
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: v.app.openArtist(parent.artist) }
                    }
                }
            }
        }
    }

    Popup {   // "More filters…": the advanced filters
        id: fp
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true; padding: 16; width: 380
        background: Rectangle { color: theme.panel; border.color: theme.line; radius: 12 }
        contentItem: Loader { active: fp.visible; sourceComponent: filterForm }
    }
    Component {
        id: filterForm
        ColumnLayout {
            width: 348; spacing: 8
            property var artists: [qsTr("— any —")].concat(mainModel.distinct("artist"))
            property var albums: [qsTr("— any —")].concat(mainModel.distinct("album"))
            Label { text: qsTr("Filters"); font.weight: Font.DemiBold; font.pixelSize: 16 }
            Label { text: qsTr("Artist") }
            ComboBox { Layout.fillWidth: true; model: parent.artists; currentIndex: Math.max(0, parent.artists.indexOf(v.uf.artist)); onActivated: v.setF("artist", currentIndex ? currentText : "") }
            Label { text: qsTr("Album") }
            ComboBox { Layout.fillWidth: true; model: parent.albums; currentIndex: Math.max(0, parent.albums.indexOf(v.uf.album)); onActivated: v.setF("album", currentIndex ? currentText : "") }
            RowLayout {
                Label { text: qsTr("Length (min) from"); Layout.fillWidth: true }
                SpinBox { from: 0; to: 600; value: (v.uf.minDuration || 0) / 60; onValueModified: v.setF("minDuration", value * 60) }
                Label { text: qsTr("to") }
                SpinBox { from: 0; to: 600; value: (v.uf.maxDuration || 0) / 60; onValueModified: v.setF("maxDuration", value * 60) }
            }
            RowLayout { Label { text: qsTr("Played at least (times)"); Layout.fillWidth: true } SpinBox { from: 0; to: 9999; value: v.uf.minPlays || 0; onValueModified: v.setF("minPlays", value) } }
            RowLayout { Label { text: qsTr("Favorites only"); Layout.fillWidth: true } Switch { checked: !!v.uf.favorite; onToggled: v.setF("favorite", checked) } }
            RowLayout { Label { text: qsTr("Added in the last 30 days"); Layout.fillWidth: true } Switch { checked: !!v.uf.recentlyAdded; onToggled: v.setF("recentlyAdded", checked) } }
            RowLayout { Label { text: qsTr("Played before"); Layout.fillWidth: true } Switch { checked: !!v.uf.recentlyPlayed; onToggled: v.setF("recentlyPlayed", checked) } }
            RowLayout {
                ActionButton { text: qsTr("Clear filters"); onClicked: { v.uf = ({}); v.genre = ""; fp.close() } }
                Item { Layout.fillWidth: true }
                ActionButton { primary: true; text: qsTr("Done"); onClicked: fp.close() }
            }
        }
    }
}