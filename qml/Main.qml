import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: win
    property string page: "songs"          // home|played|added|favorites|songs|albums|artists|folders|playlist|now|lyrics|settings
    property string prevPage: "songs"
    property string backPage: "songs"
    property int plId: 0
    property bool rightPanel: false
    property bool miniMode: false
    property bool ready: false
    property bool collapsed: false
    property var detail: ({})              // arguments of the album / artist detail pages
    property string libTab: "albums"
    property string pendingQuery: ""
    readonly property string navKey: page === "songs" || page === "albums" || page === "artists" || page === "folders" || page === "album" || page === "artist" ? "library"
        : page === "playlist" ? "playlists" : page === "home" || page === "played" || page === "added" || page === "favorites" ? page : ""

    title: pc.hasTrack ? pc.track.title + " — Cadence" : "Cadence"
    minimumWidth: 900; minimumHeight: 560
    width: 1366; height: 768
    visible: false
    color: theme.bg
    Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }
    palette {
        window: theme.bg; windowText: theme.text; base: theme.panel; alternateBase: theme.panel; text: theme.text
        button: theme.panel; buttonText: theme.text; highlight: theme.accent; highlightedText: theme.onAccent
        placeholderText: theme.muted; mid: theme.muted; toolTipBase: theme.panel; toolTipText: theme.text
    }

    // ---------- helpers used by child views (via Window.window) ----------
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function showPage(p) { page = p }
    function toggleLyrics() { if (page === "lyrics") page = prevPage; else { prevPage = page; page = "lyrics" } }
    function srcFor(p) { return p === "now" ? "NowPlaying.qml" : p === "lyrics" ? "LyricsView.qml" : p === "settings" ? "SettingsView.qml" : p === "playlist" ? "PlaylistView.qml"
        : p === "home" ? "HomeView.qml" : p === "favorites" ? "FavoritesView.qml" : p === "played" || p === "added" ? "RecentView.qml"
        : p === "album" ? "AlbumPage.qml" : p === "artist" ? "ArtistPage.qml" : "LibraryView.qml" }
    function goNav(k) {
                if (k === "library") page = ["songs", "albums", "artists", "folders"].indexOf(page) >= 0 ? page : libTab
        else if (k === "playlists") {
            if (playlists.playlists.length > 0) { plId = playlists.playlists[0].id; page = "playlist" }
            else askName(qsTr("New playlist"), "", function (n) { plId = playlists.create(n); page = "playlist" })
        } else page = k
    }
    function openAlbum(album, albumArtist) { detail = {album: album, albumArtist: albumArtist}; page = "album" }
    function openArtist(artist) { detail = {artist: artist}; page = "artist" }
    function shufflePlay(ids) { if (!ids || ids.length === 0) return; pc.shuffle = true; pc.playTracks(ids, Math.floor(Math.random() * ids.length)) }
    function searchFor(text) { pendingQuery = text; page = "songs" }
    function askName(title, initial, cb) { nameDlg.title = title; nameField.text = initial; nameDlg.cb = cb; nameDlg.open(); nameField.forceActiveFocus(); nameField.selectAll() }
    function confirm(text, cb) { confirmDlg.cb = cb; confirmText.text = text; confirmDlg.open() }
    function openMeta(id) { metaDlg.edit(id) }
    function editLyrics() { lyricsDlg.edit() }
    function toast(t) { toastText.text = t; toastBox.opacity = 1; toastTimer.restart() }
    function showMain() { if (miniMode) mini.show(); else { win.show(); win.raise(); win.requestActivate() } }
    function importPlaylist(url) {
        var r = playlists.importM3u(url)
        if (r.ok) { plId = r.id; page = "playlist" } else toast(r.error)
        var lines = []
        ;(r.missing || []).slice(0, 40).forEach(function (p) { lines.push(qsTr("missing: ") + p) })
        ;(r.unknown || []).slice(0, 40).forEach(function (p) { lines.push(qsTr("not in library: ") + p) })
        if (lines.length) { reportText.text = lines.join("\n"); reportDlg.open() }
    }
    function saveGeometry() {
        if (visibility !== Window.Windowed) return
        settings.setValue("win/w", width); settings.setValue("win/h", height); settings.setValue("win/x", x); settings.setValue("win/y", y)
    }
    function restoreGeometry() {
        width = Math.max(minimumWidth, settings.number("win/w", 1366)); height = Math.max(minimumHeight, settings.number("win/h", 768))
        var x0 = settings.number("win/x", -99999), y0 = settings.number("win/y", -99999)
        for (var i = 0; i < Qt.application.screens.length; ++i) {   // ignore positions that are no longer on any screen
            var s = Qt.application.screens[i]
            if (x0 >= s.virtualX - 20 && y0 >= s.virtualY && x0 + 120 <= s.virtualX + s.width && y0 + 60 <= s.virtualY + s.height) { x = x0; y = y0; break }
        }
    }

    Component.onCompleted: {
        restoreGeometry()
        var p = settings.text("ui/page", "songs")
        page = p === "playlist" ? "songs" : p
        rightPanel = settings.flag("ui/rightPanel", false)
        collapsed = settings.flag("ui/sideCollapsed", false)
        ready = true
        show()
        if (startupNotice !== "") { noticeText.text = startupNotice; noticeDlg.open() }
    }
    onPageChanged: {
        if (page !== "now") backPage = page
        if (["songs", "albums", "artists", "folders"].indexOf(page) >= 0) libTab = page
        if (!ready) return
        pageIn.restart()
        if (page !== "playlist") settings.setValue("ui/page", page)
    }
    onRightPanelChanged: if (ready) settings.setValue("ui/rightPanel", rightPanel)
    onCollapsedChanged: if (ready) settings.setValue("ui/sideCollapsed", collapsed)
    onWidthChanged: geoTimer.restart()
    onHeightChanged: geoTimer.restart()
    onXChanged: geoTimer.restart()
    onYChanged: geoTimer.restart()
    onClosing: (close) => { saveGeometry(); if (desktop.closeToTray()) { close.accepted = false; hide() } else Qt.quit() }
    onMiniModeChanged: { if (!ready) return; if (miniMode) { win.hide(); mini.show() } else { mini.hide(); win.show(); win.raise(); win.requestActivate() } }
    Timer { id: geoTimer; interval: 800; onTriggered: win.saveGeometry() }

    MiniPlayer { id: mini; onExpand: win.miniMode = false }

    Connections { target: pc; function onMessage(t) { win.toast(t) } }
    Connections { target: scanner; function onMessage(t) { win.toast(t) } function onImported(ids) { pc.enqueue(ids) } }
    Connections { target: playlists; function onMessage(t) { win.toast(t) } }
    Connections {
        target: desktop
        function onShowRequested() { win.showMain() }
        function onToggleRequested() { if (win.visible || mini.visible) { win.hide(); mini.hide() } else win.showMain() }
    }

    // ---------- shortcuts (application-wide; text fields keep their own keys) ----------
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Space"; onActivated: pc.togglePlayPause() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Left"; onActivated: pc.seekBy(-5000) }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Right"; onActivated: pc.seekBy(5000) }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Left"; onActivated: pc.previous() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Right"; onActivated: pc.next() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Up"; onActivated: pc.volumeBy(0.05) }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Down"; onActivated: pc.volumeBy(-0.05) }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "M"; onActivated: pc.muted = !pc.muted }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Q"; onActivated: win.rightPanel = !win.rightPanel }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "L"; onActivated: win.toggleLyrics() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "F"; onActivated: pc.toggleFavorite() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+M"; onActivated: win.miniMode = !win.miniMode }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Ctrl+Z"; onActivated: undo.undo() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Media Play"; onActivated: pc.togglePlayPause() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Media Pause"; onActivated: pc.pause() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Media Stop"; onActivated: pc.stop() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Media Next"; onActivated: pc.next() }
    Shortcut { context: Qt.ApplicationShortcut; sequence: "Media Previous"; onActivated: pc.previous() }

    // ---------- sidebar navigation row ----------
    component NavItem: Rectangle {
        id: ni
        property string icon
        property string label
        property bool on: false
        signal clicked()
        Layout.fillWidth: true; Layout.preferredHeight: 40
        radius: 7
        color: on ? theme.tint : nma.containsMouse ? win.alpha(theme.text, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; spacing: 12
            Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: ni.icon; color: ni.on ? theme.accent : theme.muted }
            Label { visible: !win.collapsed; Layout.fillWidth: true; elide: Text.ElideRight; text: ni.label; font.pixelSize: 13; font.weight: Font.Medium; color: ni.on ? theme.accent : theme.muted }
        }
        MouseArea {
            id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ni.clicked()
            ToolTip.visible: containsMouse && win.collapsed; ToolTip.text: ni.label; ToolTip.delay: 500
        }
    }

    // ---------- layout ----------
    DropArea {   // audio files and folders dragged in from a file manager
        anchors.fill: parent; keys: ["text/uri-list"]
        onDropped: (d) => { if (d.hasUrls) scanner.importPaths(d.urls) }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        RowLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

            // ----- sidebar (208 px) -----
            Rectangle {
                id: side
                Layout.fillHeight: true
                Layout.preferredWidth: win.collapsed ? 72 : 208
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                color: theme.side; clip: true
                Behavior on color { ColorAnimation { duration: 400 } }
                ColumnLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.bottomMargin: 12; spacing: 6

                    Item {   // brand
                        Layout.fillWidth: true; Layout.preferredHeight: 54
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; spacing: 12
                            Icon { Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 25; Layout.preferredHeight: 25; name: "cadence-logo"; color: theme.accent }
                            Label { visible: !win.collapsed; Layout.alignment: Qt.AlignVCenter; text: "Cadence"; font.pixelSize: 25; font.weight: Font.DemiBold }
                        }
                    }
                    Label { visible: !win.collapsed; text: qsTr("YOUR MUSIC"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.muted }

                    Repeater {
                        model: [{k: "home", i: "home", t: qsTr("Home")}, {k: "played", i: "clock", t: qsTr("Recently played")}, {k: "added", i: "plus", t: qsTr("Recently added")},
                                {k: "favorites", i: "heart", t: qsTr("Favorites")}, {k: "library", i: "library", t: qsTr("Library")}, {k: "playlists", i: "list", t: qsTr("Playlists")}]
                        delegate: NavItem {
                            required property var modelData
                            icon: modelData.i; label: modelData.t; on: win.navKey === modelData.k
                            onClicked: win.goNav(modelData.k)
                        }
                    }

                    RowLayout {   // pinned playlists
                        visible: !win.collapsed; Layout.topMargin: 14; Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: qsTr("PLAYLISTS"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.muted }
                        IconButton { size: 24; glyph: "+"; color: theme.muted; tip: qsTr("New playlist"); onClicked: win.askName(qsTr("New playlist"), "", function (n) { win.plId = playlists.create(n); win.page = "playlist" }) }
                        IconButton { size: 24; glyph: "⤓"; color: theme.muted; tip: qsTr("Import M3U / M3U8"); onClicked: importDlg.open() }
                    }
                    ListView {
                        visible: !win.collapsed
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 13; model: playlists.playlists
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            id: pl
                            required property var modelData
                            readonly property bool on: win.page === "playlist" && win.plId === modelData.id
                            width: ListView.view.width; height: 19
                            Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 5; color: win.alpha(theme.accent, 0.35); visible: pdz.containsDrag }
                            Label { width: parent.width; elide: Text.ElideRight; text: pl.modelData.name; font.pixelSize: 13; color: pl.on || plMa.containsMouse ? theme.accent : theme.muted }
                            MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.plId = pl.modelData.id; win.page = "playlist" } }
                            DropArea { id: pdz; anchors.fill: parent; keys: ["track"]; onDropped: (d) => playlists.addTracks(pl.modelData.id, d.source.ids()) }
                        }
                    }
                    Item { visible: win.collapsed; Layout.fillHeight: true }

                    ColumnLayout {   // local library summary
                        visible: !win.collapsed; Layout.fillWidth: true; spacing: 12
                        RowLayout {
                            spacing: 12
                            Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; name: "folder"; color: theme.muted }
                            Label { text: qsTr("All music, right here."); font.pixelSize: 11; color: theme.muted }
                        }
                        Label { text: scanner.scanning ? qsTr("Scanning… %1 / %2").arg(scanner.progress).arg(scanner.total) : scanner.summary; font.pixelSize: 11; color: theme.muted }
                    }

                    RowLayout {   // settings + collapse
                        Layout.fillWidth: true; Layout.preferredHeight: 42; Layout.topMargin: 6; spacing: 12
                        Icon { Layout.preferredWidth: 20; Layout.preferredHeight: 20; Layout.leftMargin: 0; name: "settings"; color: win.page === "settings" ? theme.accent : theme.muted
                               MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "settings" } }
                        Label {
                            visible: !win.collapsed; text: qsTr("Settings"); font.pixelSize: 13; color: win.page === "settings" ? theme.accent : theme.muted
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "settings" }
                        }
                        Item { Layout.fillWidth: true }
                        IconButton { visible: !win.collapsed; size: 28; iconSize: 20; icon: "collapse"; color: theme.muted; tip: qsTr("Collapse sidebar"); onClicked: win.collapsed = true }
                    }
                    IconButton { visible: win.collapsed; Layout.alignment: Qt.AlignHCenter; size: 28; iconSize: 20; icon: "collapse"; rotation: 180; color: theme.muted; tip: qsTr("Expand sidebar"); onClicked: win.collapsed = false }
                }
            }

            // ----- page area -----
            SplitView {
                id: split
                Layout.fillWidth: true; Layout.fillHeight: true
                onResizingChanged: if (!resizing && win.ready && queueHost.visible) settings.setValue("ui/panelW", queueHost.width)
                handle: Rectangle { implicitWidth: 0; color: "transparent" }

                Loader {
                    id: content
                    SplitView.fillWidth: true; SplitView.minimumWidth: 400
                    source: win.srcFor(win.page)
                    transform: Translate { id: pageShift; y: 0 }
                    onLoaded: {
                        if (item.kind !== undefined) item.kind = Qt.binding(function () { return win.page })
                        if (item.plId !== undefined) item.plId = Qt.binding(function () { return win.plId })
                        if (item.args !== undefined) item.args = Qt.binding(function () { return win.detail })
                    }
                    ParallelAnimation {   // page change: fade + short slide up
                        id: pageIn
                        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                        NumberAnimation { target: pageShift; property: "y"; from: 10; to: 0; duration: 280; easing.type: Easing.OutCubic }
                    }
                }

                Item {
                    id: queueHost
                    opacity: win.rightPanel ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    SplitView.preferredWidth: settings.number("ui/panelW", 340); SplitView.minimumWidth: 260
                    QueuePanel { anchors.fill: parent; anchors.margins: 12; anchors.leftMargin: 4; radius: 12 }
                }
            }
        }

        // ----- playback bar (102 px) -----
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 102
            color: theme.side
            Behavior on color { ColorAnimation { duration: 400 } }
            Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: theme.line }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24; spacing: 12

                RowLayout {   // current track
                    Layout.preferredWidth: 310; Layout.maximumWidth: 310; Layout.alignment: Qt.AlignVCenter; spacing: 12
                    Cover {
                        Layout.preferredWidth: 54; Layout.preferredHeight: 54; corner: 0.11; trackId: pc.track.id || 0; px: 128
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "now" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing")
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "now" } }
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted; text: pc.hasTrack ? pc.track.artist + (pc.track.album ? " · " + pc.track.album : "") : "" }
                    }
                    IconButton { size: 28; iconSize: 20; icon: "heart"; enabled: pc.hasTrack; color: pc.track.favorite ? theme.accent : theme.muted; tip: qsTr("Favorite"); onClicked: pc.toggleFavorite() }
                }

                ColumnLayout {   // transport + progress
                    Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 6
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 8
                        IconButton { size: 36; iconSize: 20; icon: "shuffle"; color: pc.shuffle ? theme.accent : theme.muted; tip: qsTr("Shuffle"); onClicked: pc.shuffle = !pc.shuffle }
                        IconButton { size: 36; iconSize: 19; icon: "prev"; enabled: pc.canPrevious; color: theme.text; tip: qsTr("Previous"); onClicked: pc.previous() }
                        Item {
                            id: pp
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36
                            Rectangle {
                                anchors.fill: parent; radius: 18; color: theme.accent
                                opacity: ppm.pressed ? 0.85 : 1
                                scale: ppm.pressed ? 0.95 : 1
                                Behavior on scale { NumberAnimation { duration: 100 } }
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            Icon { anchors.centerIn: parent; width: 20; height: 20; name: pc.playing ? "pause" : "play"; color: theme.onAccent }
                            MouseArea {
                                id: ppm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pc.togglePlayPause()
                                ToolTip.visible: containsMouse; ToolTip.text: qsTr("Play / Pause"); ToolTip.delay: 600
                            }
                        }
                        IconButton { size: 36; iconSize: 19; icon: "next"; enabled: pc.canNext; color: theme.text; tip: qsTr("Next"); onClicked: pc.next() }
                        IconButton { size: 36; iconSize: 20; icon: "repeat"; color: pc.repeat > 0 ? theme.accent : theme.muted; tip: pc.repeat === 2 ? qsTr("Repeat one") : qsTr("Repeat"); onClicked: pc.repeat = (pc.repeat + 1) % 3 }
                    }
                    SeekRow { Layout.fillWidth: true; Layout.maximumWidth: 500; Layout.alignment: Qt.AlignHCenter }
                }

                RowLayout {   // volume, queue, lyrics, mini-player
                    Layout.preferredWidth: 250; Layout.alignment: Qt.AlignVCenter; spacing: 10
                    VolumeControl {}
                    IconButton { size: 28; iconSize: 20; icon: "list"; color: win.rightPanel ? theme.accent : theme.muted; tip: qsTr("Queue (Q)"); onClicked: win.rightPanel = !win.rightPanel }
                    IconButton { size: 28; iconSize: 20; icon: "lyrics"; color: win.page === "lyrics" ? theme.accent : theme.muted; tip: qsTr("Lyrics (L)"); onClicked: win.toggleLyrics() }
                    IconButton { size: 28; iconSize: 20; icon: "mini"; color: theme.muted; tip: qsTr("Mini-player (Ctrl+M)"); onClicked: win.miniMode = true }
                }
            }
        }
    }

    // ---------- toast and dialogs ----------
    Rectangle {
        id: toastBox
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        anchors.bottomMargin: 120 - 16 * (1 - opacity)      // slides up while fading in
        width: Math.min(parent.width - 40, toastText.implicitWidth + 36); height: toastText.implicitHeight + 22
        radius: 8; color: theme.text; opacity: 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Label { id: toastText; anchors.centerIn: parent; width: parent.width - 36; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 13; color: theme.bg }
        Timer { id: toastTimer; interval: 4500; onTriggered: toastBox.opacity = 0 }
    }

    MetadataDialog { id: metaDlg }
    LyricsEditor { id: lyricsDlg }
    FileDialog { id: importDlg; nameFilters: [qsTr("Playlists (*.m3u *.m3u8)")]; onAccepted: win.importPlaylist(selectedFile.toString()) }

    Dialog {
        id: nameDlg
        property var cb
        parent: Overlay.overlay; anchors.centerIn: parent; modal: true; width: 360
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: if (cb && nameField.text.trim() !== "") cb(nameField.text.trim())
        TextField { id: nameField; width: parent.width; onAccepted: nameDlg.accept() }
    }
    Dialog {
        id: confirmDlg
        property var cb
        parent: Overlay.overlay; anchors.centerIn: parent; modal: true; width: 420
        title: qsTr("Please confirm"); standardButtons: Dialog.Yes | Dialog.No
        onAccepted: if (cb) cb()
        Label { id: confirmText; width: parent.width; wrapMode: Text.Wrap }
    }
    Dialog {
        id: noticeDlg
        parent: Overlay.overlay; anchors.centerIn: parent; modal: true; width: 480
        title: qsTr("Library database"); standardButtons: Dialog.Ok
        Label { id: noticeText; width: parent.width; wrapMode: Text.Wrap }
    }
    Dialog {
        id: reportDlg
        parent: Overlay.overlay; anchors.centerIn: parent; modal: true
        width: Math.min(win.width - 40, 640); height: Math.min(win.height - 40, 420)
        title: qsTr("Playlist import report"); standardButtons: Dialog.Ok
        ScrollView { anchors.fill: parent; Label { id: reportText; width: reportDlg.width - 60; wrapMode: Text.WrapAnywhere; font.pixelSize: 12 } }
    }
}