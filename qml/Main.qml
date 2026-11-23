import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: win
    property string page: "songs"          // now|songs|albums|artists|folders|favorites|played|added|lyrics|settings|playlist
    property string prevPage: "songs"
    property string backPage: "songs"
    property int plId: 0
    property bool rightPanel: false
    property bool miniMode: false
    property bool ready: false
    readonly property var tabs: [
        {k: "songs", g: "♪", t: qsTr("Songs")}, {k: "albums", g: "◉", t: qsTr("Albums")}, {k: "artists", g: "☺", t: qsTr("Artists")}, {k: "folders", g: "▣", t: qsTr("Folders")},
        {k: "favorites", g: "♥", t: qsTr("Favorites")}, {k: "played", g: "↺", t: qsTr("Recently played")}, {k: "added", g: "✦", t: qsTr("Recently added")}]
    readonly property bool onTab: tabs.some(function (t) { return t.k === page })

    title: pc.hasTrack ? pc.track.title + " — Cadence" : "Cadence"
    minimumWidth: 780; minimumHeight: 540
    width: 1100; height: 720
    visible: false
    color: theme.bg
    Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
    palette {
        window: theme.bg; windowText: theme.text; base: theme.surface; alternateBase: theme.surface; text: theme.text
        button: theme.surface; buttonText: theme.text; highlight: theme.accent; highlightedText: theme.onAccent
        placeholderText: theme.subtext; mid: theme.subtext; toolTipBase: theme.surface; toolTipText: theme.text
    }

    // ---------- helpers used by child views (via Window.window) ----------
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function showPage(p) { page = p }
    function toggleLyrics() { if (page === "lyrics") page = prevPage; else { prevPage = page; page = "lyrics" } }
    function titleFor(p) {
        for (var i = 0; i < tabs.length; ++i) if (tabs[i].k === p) return tabs[i].t
        return p === "now" ? qsTr("Now Playing") : p === "lyrics" ? qsTr("Lyrics") : p === "settings" ? qsTr("Settings") : qsTr("Playlist")
    }
    function srcFor(p) { return p === "now" ? "NowPlaying.qml" : p === "lyrics" ? "LyricsView.qml" : p === "settings" ? "SettingsView.qml" : p === "playlist" ? "PlaylistView.qml" : "LibraryView.qml" }
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
        width = Math.max(minimumWidth, settings.number("win/w", 1100)); height = Math.max(minimumHeight, settings.number("win/h", 720))
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
        ready = true
        show()
        if (startupNotice !== "") { noticeText.text = startupNotice; noticeDlg.open() }
    }
    onPageChanged: {
        if (page !== "now") backPage = page
        if (!ready) return
        pageIn.restart()
        if (page !== "playlist") settings.setValue("ui/page", page)
    }
    onRightPanelChanged: if (ready) settings.setValue("ui/rightPanel", rightPanel)
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

    // ---------- reusable pill chip (playlists row) ----------
    component Chip: Rectangle {
        id: chip
        property string label
        property bool on: false
        signal clicked()
        signal dropped(var ids)
        height: 38; width: lbl.implicitWidth + 32; radius: 19
        color: dz.containsDrag ? win.alpha(theme.accent, 0.4) : on ? win.alpha(theme.accent, 0.22) : cma.containsMouse ? win.alpha(theme.text, 0.13) : win.alpha(theme.text, 0.07)
        Behavior on color { ColorAnimation { duration: 140 } }
        Label { id: lbl; anchors.centerIn: parent; text: chip.label; font.pixelSize: 14; font.weight: Font.DemiBold; color: chip.on ? theme.accent : theme.text }
        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
        DropArea { id: dz; anchors.fill: parent; keys: ["track"]; onDropped: (d) => chip.dropped(d.source.ids()) }
    }

    // ---------- layout ----------
    DropArea {   // audio files and folders dragged in from a file manager
        anchors.fill: parent; keys: ["text/uri-list"]
        onDropped: (d) => { if (d.hasUrls) scanner.importPaths(d.urls) }
    }

    ColumnLayout {
        anchors.fill: parent; spacing: 0

        // ----- header: big page title + round action buttons (collapses in full screen) -----
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: win.visibility === Window.FullScreen ? 0 : 72
            clip: true
            opacity: win.visibility === Window.FullScreen ? 0 : 1
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 16; spacing: 8
                IconButton { visible: win.page === "now"; size: 42; tonal: true; glyph: "←"; tip: qsTr("Back"); onClicked: win.page = win.backPage }
                Label { text: win.titleFor(win.page); font.pixelSize: 30; font.weight: Font.ExtraBold; font.letterSpacing: -0.35; elide: Text.ElideRight; Layout.fillWidth: true }
                Label { visible: scanner.scanning; text: qsTr("Scanning… %1 / %2").arg(scanner.progress).arg(scanner.total); font.pixelSize: 13; color: theme.subtext; Layout.rightMargin: 6 }
                IconButton { size: 42; tonal: true; glyph: "♫"; color: win.page === "now" ? theme.accent : theme.text; tip: qsTr("Now Playing"); onClicked: win.page = "now" }
                IconButton { size: 42; tonal: true; glyph: "≣"; color: win.page === "lyrics" ? theme.accent : theme.text; tip: qsTr("Lyrics"); onClicked: win.page = "lyrics" }
                IconButton { size: 42; tonal: true; glyph: "⚙"; color: win.page === "settings" ? theme.accent : theme.text; tip: qsTr("Settings"); onClicked: win.page = "settings" }
                IconButton { size: 42; tonal: true; glyph: "↶"; enabled: undo.canUndo; tip: undo.canUndo ? qsTr("Undo: %1").arg(undo.label) : qsTr("Undo"); onClicked: undo.undo() }
                IconButton { size: 42; tonal: true; glyph: "❐"; tip: qsTr("Mini-player"); onClicked: win.miniMode = true }
            }
        }
        ProgressBar { visible: scanner.scanning; Layout.fillWidth: true; Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.preferredHeight: 3; from: 0; to: Math.max(1, scanner.total); value: scanner.progress }

        // ----- playlist chips (drop targets) -----
        Flickable {
            id: chipFlick
            visible: win.onTab || win.page === "playlist"
            Layout.fillWidth: true; Layout.preferredHeight: visible ? 52 : 0
            Layout.leftMargin: 24; Layout.rightMargin: 24
            clip: true; contentWidth: chipRow.width; contentHeight: height
            flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: chipRow
                y: 7; spacing: 8
                Chip { label: "+  " + qsTr("New playlist"); onClicked: win.askName(qsTr("New playlist"), "", function (n) { win.plId = playlists.create(n); win.page = "playlist" }) }
                Chip { label: "⤓  " + qsTr("Import M3U / M3U8"); onClicked: importDlg.open() }
                Repeater {
                    model: playlists.playlists
                    delegate: Chip {
                        required property var modelData
                        label: modelData.name + "  ·  " + modelData.count
                        on: win.page === "playlist" && win.plId === modelData.id
                        onClicked: { win.plId = modelData.id; win.page = "playlist" }
                        onDropped: (ids) => playlists.addTracks(modelData.id, ids)
                    }
                }
            }
        }

        SplitView {
            id: split
            Layout.fillWidth: true; Layout.fillHeight: true
            onResizingChanged: if (!resizing && win.ready && queueHost.visible) settings.setValue("ui/panelW", queueHost.width)
            handle: Rectangle { implicitWidth: 0; color: "transparent" }

            Loader {
                id: content
                SplitView.fillWidth: true; SplitView.minimumWidth: 340
                source: win.srcFor(win.page)
                transform: Translate { id: pageShift; y: 0 }
                onLoaded: {
                    if (item.kind !== undefined) item.kind = Qt.binding(function () { return win.page })
                    if (item.plId !== undefined) item.plId = Qt.binding(function () { return win.plId })
                }
                ParallelAnimation {   // page change: fade + short slide up
                    id: pageIn
                    NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                    NumberAnimation { target: pageShift; property: "y"; from: 12; to: 0; duration: 320; easing.type: Easing.OutCubic }
                }
            }

            Item {
                id: queueHost
                opacity: win.rightPanel ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                SplitView.preferredWidth: settings.number("ui/panelW", 340); SplitView.minimumWidth: 260
                QueuePanel { anchors.fill: parent; anchors.margins: 8; anchors.rightMargin: 16; radius: 24 }
            }
        }

        // ----- floating capsule mini-player (LastWave) -----
        Rectangle {
            id: capsule
            visible: win.page !== "now"
            Layout.fillWidth: true; Layout.maximumWidth: 680; Layout.preferredHeight: 72
            Layout.alignment: Qt.AlignHCenter
            Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 4
            radius: 36; color: theme.surface
            border.width: 1; border.color: win.alpha(theme.text, 0.06)
            Behavior on color { ColorAnimation { duration: 500 } }
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 14; anchors.bottomMargin: 4; spacing: 0
                Cover {
                    Layout.preferredWidth: 54; Layout.preferredHeight: 54; corner: 0.5; trackId: pc.track.id || 0; px: 128
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.page = "now" }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 12; Layout.rightMargin: 12; spacing: 1
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: -0.2; text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing") }
                    Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; opacity: 0.78; text: pc.hasTrack ? pc.track.artist : "" }
                    TapHandler { onTapped: win.page = "now" }
                }
                IconButton { size: 36; tonal: true; icon: "prev"; enabled: pc.canPrevious; tip: qsTr("Previous"); onClicked: pc.previous() }
                Item {
                    id: cplay
                    Layout.leftMargin: 6; Layout.rightMargin: 6; Layout.preferredWidth: 42; Layout.preferredHeight: 42
                    Rectangle {
                        anchors.fill: parent; color: theme.accent
                        radius: pc.playing ? width / 2 : width * 0.32
                        opacity: cma2.pressed ? 0.85 : 1
                        Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 500 } }
                    }
                    Icon { anchors.centerIn: parent; width: 22; height: 22; name: pc.playing ? "pause" : "play"; color: theme.onAccent }
                    MouseArea {
                        id: cma2; anchors.fill: parent; hoverEnabled: true
                        onClicked: pc.togglePlayPause()
                        ToolTip.visible: containsMouse; ToolTip.text: qsTr("Play / Pause"); ToolTip.delay: 600
                    }
                }
                IconButton { size: 36; tonal: true; icon: "next"; enabled: pc.canNext; tip: qsTr("Next"); onClicked: pc.next() }
                IconButton { Layout.leftMargin: 6; size: 40; tonal: true; glyph: "☰"; color: win.rightPanel ? theme.accent : theme.text; tip: qsTr("Queue (Q)"); onClicked: win.rightPanel = !win.rightPanel }
            }
            Rectangle {   // thin playback progress line along the bottom of the capsule
                x: 30; y: parent.height - 9; width: parent.width - 60; height: 3; radius: 1.5
                color: win.alpha(theme.text, 0.15)
                Rectangle { width: pc.duration > 0 ? parent.width * Math.min(1, pc.position / pc.duration) : 0; height: parent.height; radius: 1.5; color: theme.accent }
            }
        }

        // ----- floating pill navigation with sliding highlight; only the selected tab shows its caption -----
        Rectangle {
            id: nav
            visible: win.page !== "now"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: navRow.width + 8; Layout.preferredHeight: 64
            Layout.topMargin: 8; Layout.bottomMargin: 12
            radius: 32; color: theme.surface
            border.width: 1; border.color: win.alpha(theme.text, 0.06)
            Behavior on color { ColorAnimation { duration: 500 } }
            Rectangle {   // highlight bubble
                y: 4; height: 56; radius: 28; color: win.alpha(theme.accent, 0.22)
                x: navRow.current ? 4 + navRow.current.x : 4
                width: navRow.current ? navRow.current.width : 0
                opacity: win.onTab ? 1 : 0
                Behavior on x { enabled: win.ready; NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on width { enabled: win.ready; NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
            Row {
                id: navRow
                x: 4; y: 4; height: 56
                property Item current: null
                Repeater {
                    model: win.tabs
                    delegate: Item {
                        id: nt
                        required property var modelData
                        readonly property bool on: win.page === modelData.k
                        readonly property real contentW: 20 + (capBox.width > 0 ? 8 + capBox.width : 0)
                        width: 56 + capBox.width; height: 56
                        onOnChanged: if (on) navRow.current = nt
                        Component.onCompleted: if (on) navRow.current = nt
                        Label {
                            x: (nt.width - nt.contentW) / 2; anchors.verticalCenter: parent.verticalCenter
                            text: nt.modelData.g; font.pixelSize: 21
                            color: nt.on ? theme.accent : theme.subtext
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        Item {
                            id: capBox
                            x: (nt.width - nt.contentW) / 2 + 28; height: parent.height; clip: true
                            width: nt.on ? cap.implicitWidth : 0
                            Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                            Label { id: cap; anchors.verticalCenter: parent.verticalCenter; text: nt.modelData.t; font.pixelSize: 13; font.weight: Font.DemiBold; color: theme.accent; opacity: nt.on ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 200 } } }
                        }
                        MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.page = nt.modelData.k
                            ToolTip.visible: containsMouse && !nt.on; ToolTip.text: nt.modelData.t; ToolTip.delay: 600 }
                    }
                }
            }
        }
    }

    // ---------- toast and dialogs ----------
    Rectangle {
        id: toastBox
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        anchors.bottomMargin: (win.page === "now" ? 40 : 176) - 16 * (1 - opacity)      // slides up while fading in
        width: Math.min(parent.width - 40, toastText.implicitWidth + 36); height: toastText.implicitHeight + 22
        radius: height / 2; color: theme.text; opacity: 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Label { id: toastText; anchors.centerIn: parent; width: parent.width - 36; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 14; color: theme.bg }
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