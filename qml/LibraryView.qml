import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property string kind: "songs"          // songs|albums|artists|folders|favorites|played|added
    property var drill: null               // drilled-into group filter
    property var uf: ({})                  // user filters
    property var sel: ({})                 // selected track ids (songs mode)
    property string query: ""
    property string sortKey: "title"
    property bool desc: false
    readonly property string mode: drill ? "songs" : ({albums: "albums", artists: "artists", folders: "folders"})[kind] || "songs"
    readonly property bool grid: (settings.revision, settings.flag("ui/grid"))
    readonly property bool compact: (settings.revision, settings.flag("ui/compact"))
    readonly property var sortOpts: mode === "songs"
        ? [{v: "title", t: qsTr("Title")}, {v: "artist", t: qsTr("Artist")}, {v: "album", t: qsTr("Album")}, {v: "trackNo", t: qsTr("Track no.")},
           {v: "duration", t: qsTr("Length")}, {v: "added", t: qsTr("Date added")}, {v: "played", t: qsTr("Last played")}, {v: "plays", t: qsTr("Play count")}]
        : [{v: "title", t: qsTr("Name")}, {v: "count", t: qsTr("Tracks")}, {v: "added", t: qsTr("Date added")}]

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    function resetSort() { sortKey = kind === "played" ? "played" : kind === "added" ? "added" : "title"; desc = kind === "played" || kind === "added" }
    function setF(k, val) { var o = Object.assign({}, uf); if (!val) delete o[k]; else o[k] = val; uf = o }
    function buildFilters() {
        var f = Object.assign({}, uf)
        if (query) f.text = query
        if (kind === "favorites") f.favorite = true
        if (kind === "played") f.recentlyPlayed = true
        if (kind === "added") f.recentlyAdded = true
        if (drill) f = Object.assign(f, drill)
        return f
    }
    function more(view) { if (view.contentHeight - view.contentY - view.height < 800) lib.loadMore() }
    function menuFor(info) {
        var multi = mode === "songs" && sel[info.id] && Object.keys(sel).length > 1
        ctx.ids = multi ? Object.keys(sel).map(Number) : lib.idsFor(info.i)
        ctx.single = mode === "songs" && !multi ? info.id : 0
        ctx.fav = info.fav
        ctx.popup()
    }
    function clicked(info, m) {
        if (m.button === Qt.RightButton) { menuFor(info); return }
        if (mode === "albums") drill = {album: info.album, albumArtist: info.albumArtist}
        else if (mode === "artists") drill = {artist: info.artist}
        else if (mode === "folders") drill = {folder: info.folder}
        else {
            var s = (m.modifiers & Qt.ControlModifier) ? Object.assign({}, sel) : ({})
            if (s[info.id] && (m.modifiers & Qt.ControlModifier)) delete s[info.id]; else s[info.id] = true
            sel = s
        }
    }
    function sub(info) {
        if (mode === "songs") return info.artist + (info.album ? " — " + info.album : "")
        if (mode === "albums") return (info.albumArtist || info.artist) + " · " + qsTr("%1 tracks").arg(info.count)
        if (mode === "artists") return qsTr("%1 tracks").arg(info.count) + " · " + qsTr("%1 albums").arg(info.extra)
        return info.folder
    }
    onKindChanged: { drill = null; uf = ({}); sel = ({}); search.text = ""; query = ""; resetSort() }
    Component.onCompleted: resetSort()

    LibraryModel { id: lib; mode: v.mode; sort: v.sortKey; descending: v.desc; filters: v.buildFilters() }
    TrackMenu { id: ctx; app: v.app }
    Timer { id: deb; interval: 200; onTriggered: v.query = search.text }
    Shortcut { sequence: "Ctrl+A"; enabled: v.visible && v.mode === "songs"; onActivated: { var s = ({}); lib.allIds().forEach(function (i) { s[i] = true }); v.sel = s } }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 4; anchors.bottomMargin: 8; spacing: 6
        RowLayout {
            Layout.preferredHeight: 44; spacing: 6
            IconButton { visible: v.drill !== null; size: 34; glyph: "←"; tip: qsTr("Back"); onClicked: { v.drill = null; v.sel = ({}) } }
            Rectangle {   // "Play all": accent text button, as in Harmonoid's library header
                id: pa
                enabled: lib.total > 0
                Layout.preferredHeight: 40; Layout.preferredWidth: paRow.implicitWidth + 20
                radius: 4; opacity: enabled ? 1 : 0.4
                color: paMa.containsMouse ? v.alpha(theme.accent, 0.12) : "transparent"
                RowLayout {
                    id: paRow; anchors.centerIn: parent; spacing: 4
                    Icon { Layout.preferredWidth: 22; Layout.preferredHeight: 22; name: "play"; color: theme.accent }
                    Label { text: qsTr("Play all"); color: theme.accent; font.pixelSize: 15 }
                }
                MouseArea { id: paMa; anchors.fill: parent; hoverEnabled: true; enabled: pa.enabled; cursorShape: Qt.PointingHandCursor; onClicked: pc.playTracks(lib.allIds()) }
            }
            Item { Layout.fillWidth: true }
            TextField {
                id: search
                Layout.fillWidth: true; Layout.maximumWidth: 280; Layout.minimumWidth: 120; Layout.preferredHeight: 44
                placeholderText: qsTr("Search title, artist, album, genre…")
                onTextChanged: deb.restart()
                background: Rectangle { radius: 22; color: theme.surface; border.width: search.activeFocus ? 2 : 0; border.color: theme.accent }
            }
            Button { flat: true; text: qsTr("Filters") + (Object.keys(v.uf).length ? " ●" : ""); onClicked: fp.open() }
            ComboBox {
                id: sortBox
                textRole: "t"; valueRole: "v"; model: v.sortOpts
                currentIndex: Math.max(0, indexOfValue(v.sortKey))
                onActivated: v.sortKey = currentValue
            }
            IconButton { size: 34; glyph: v.desc ? "↓" : "↑"; color: theme.subtext; tip: qsTr("Sort direction"); onClicked: v.desc = !v.desc }
            IconButton { size: 34; glyph: v.grid ? "☰" : "▦"; color: theme.subtext; tip: v.grid ? qsTr("List view") : qsTr("Album grid"); onClicked: settings.setValue("ui/grid", !v.grid) }
            IconButton { size: 34; glyph: "⇕"; active: v.compact; color: v.compact ? theme.accent : theme.subtext; tip: qsTr("Compact rows"); onClicked: settings.setValue("ui/compact", !v.compact) }
        }
        Label {
            color: theme.subtext; font.pixelSize: 12
            text: qsTr("%1 items").arg(lib.total) + (Object.keys(v.sel).length ? "  ·  " + qsTr("%1 selected").arg(Object.keys(v.sel).length) : "")
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            ListView {
                id: list
                anchors.fill: parent; visible: !v.grid; clip: true
                model: v.grid ? null : lib; delegate: listRow
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                onContentYChanged: v.more(list)
                onCountChanged: v.more(list)
            }
            GridView {
                id: gv
                anchors.fill: parent; visible: v.grid; clip: true
                cellWidth: 164; cellHeight: 228
                model: v.grid ? lib : null; delegate: gridCell
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                onContentYChanged: v.more(gv)
                onCountChanged: v.more(gv)
            }
            Label {
                visible: lib.total === 0; anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; color: theme.subtext
                text: scanner.folders.length === 0 ? qsTr("No music yet.\nAdd a folder in Settings, or drop one onto this window.") : qsTr("Nothing matches.")
            }
        }
    }

    Component {
        id: listRow
        Rectangle {
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
            required property var durationMs
            required property bool favorite
            readonly property var info: ({i: index, id: trackId, title: title, artist: artist, album: album, albumArtist: albumArtist, folder: folder, count: count, extra: extra, fav: favorite})
            readonly property bool cur: v.mode === "songs" && pc.track.id === trackId
            width: ListView.view ? ListView.view.width : 0
            height: v.compact ? 40 : 64
            radius: 16
            color: v.sel[trackId] ? v.alpha(theme.accent, 0.2) : ma.containsMouse ? v.alpha(theme.text, 0.06) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
            MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => v.clicked(row.info, m)
                onDoubleClicked: if (v.mode === "songs") pc.playTracks(lib.allIds(), row.index)
            }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: v.mode === "songs" ? 28 : 8; anchors.rightMargin: 8; spacing: 12
                              Cover { visible: !v.compact; Layout.preferredWidth: 48; Layout.preferredHeight: 48; corner: 0.22; trackId: row.trackId; px: 96 }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 15; font.weight: row.cur ? Font.DemiBold : Font.Normal; color: row.cur ? theme.accent : theme.text; text: row.title || qsTr("(Unknown)") }
                    Label { visible: !v.compact; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; color: theme.subtext; text: v.sub(row.info) }
                }
                Label { visible: v.compact; Layout.preferredWidth: 220; elide: Text.ElideRight; font.pixelSize: 13; color: theme.subtext; text: v.sub(row.info) }
                Label { text: v.fmt(row.durationMs); font.pixelSize: 13; color: theme.subtext }
                IconButton { visible: v.mode === "songs"; size: 28; glyph: row.favorite ? "♥" : "♡"; color: row.favorite ? theme.accent : theme.subtext; onClicked: pc.setFavorite(row.trackId, !row.favorite) }
                IconButton { visible: v.mode !== "songs"; size: 30; icon: "play"; color: theme.accent; tip: qsTr("Play"); onClicked: pc.playTracks(lib.idsFor(row.index)) }
            }
            Item {   // drag handle: songs onto the queue or a playlist
                id: grip
                visible: v.mode === "songs"
                x: 2; y: 0; width: 24; height: row.height
                z: Drag.active ? 10 : 1
                Drag.active: gma.drag.active
                Drag.keys: ["track"]
                function ids() { return v.sel[row.trackId] ? Object.keys(v.sel).map(Number) : [row.trackId] }
                Label { anchors.centerIn: parent; text: "⋮⋮"; color: theme.subtext }
                MouseArea { id: gma; anchors.fill: parent; drag.target: grip; onReleased: { grip.Drag.drop(); grip.x = 2; grip.y = 0 } }
            }
        }
    }

    Component {
        id: gridCell
        Item {
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
            required property bool favorite
            readonly property var info: ({i: index, id: trackId, title: title, artist: artist, album: album, albumArtist: albumArtist, folder: folder, count: count, extra: extra, fav: favorite})
            width: 164; height: 228
            Rectangle {
                anchors.fill: parent; anchors.margins: 4; radius: 20
                color: v.sel[cell.trackId] ? v.alpha(theme.accent, 0.2) : gma2.containsMouse ? v.alpha(theme.text, 0.06) : "transparent"
                MouseArea {
                    id: gma2; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (m) => v.clicked(cell.info, m)
                    onDoubleClicked: if (v.mode === "songs") pc.playTracks(lib.allIds(), cell.index)
                }
                Cover { x: 4; y: 4; width: 148; height: 148; corner: 0.12; trackId: cell.trackId; px: 320; scale: gma2.containsMouse ? 1.04 : 1; Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
                IconButton { x: 110; y: 110; size: 36; filled: true; icon: "play"; color: theme.onAccent; visible: gma2.containsMouse; onClicked: pc.playTracks(v.mode === "songs" ? lib.allIds() : lib.idsFor(cell.index), v.mode === "songs" ? cell.index : 0) }
                Label { x: 4; y: 160; width: 148; elide: Text.ElideRight; font.pixelSize: 15; font.weight: Font.Medium; text: cell.title || qsTr("(Unknown)") }
                Label { x: 4; y: 182; width: 148; elide: Text.ElideRight; font.pixelSize: 13; color: theme.subtext; text: v.sub(cell.info) }
            }
        }
    }

    Popup {
        id: fp
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true; padding: 16; width: 380
        contentItem: Loader { active: fp.visible; sourceComponent: filterForm }
    }
    Component {
        id: filterForm
        ColumnLayout {
            width: 348; spacing: 8
            property var artists: [qsTr("— any —")].concat(lib.distinct("artist"))
            property var albums: [qsTr("— any —")].concat(lib.distinct("album"))
            property var genres: [qsTr("— any —")].concat(lib.distinct("genre"))
            Label { text: qsTr("Filters"); font.bold: true; font.pixelSize: 16 }
            Label { text: qsTr("Artist") }
            ComboBox { Layout.fillWidth: true; model: parent.artists; currentIndex: Math.max(0, parent.artists.indexOf(v.uf.artist)); onActivated: v.setF("artist", currentIndex ? currentText : "") }
            Label { text: qsTr("Album") }
            ComboBox { Layout.fillWidth: true; model: parent.albums; currentIndex: Math.max(0, parent.albums.indexOf(v.uf.album)); onActivated: v.setF("album", currentIndex ? currentText : "") }
            Label { text: qsTr("Genre") }
            ComboBox { Layout.fillWidth: true; model: parent.genres; currentIndex: Math.max(0, parent.genres.indexOf(v.uf.genre)); onActivated: v.setF("genre", currentIndex ? currentText : "") }
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
                Button { text: qsTr("Clear filters"); onClicked: { v.uf = ({}); fp.close() } }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Done"); onClicked: fp.close() }
            }
        }
    }
}