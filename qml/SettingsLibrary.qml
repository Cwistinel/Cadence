import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    readonly property var app: Window.window
    property int cacheBytes: 0
    function refreshCache() { cacheBytes = scanner.artworkCacheBytes() }
    function mb(b) { return b < 1024 * 1024 ? qsTr("%1 KB").arg(Math.round(b / 1024)) : qsTr("%1 MB").arg((b / 1048576).toFixed(b < 10485760 ? 1 : 0)) }
    function doBackup(url, over) {
        var r = backup.create(url, over)
        if (r.ok) app.toast(qsTr("Backup saved"))
        else if (r.error === "exists") app.confirm(qsTr("The file already exists. Overwrite it?"), function () { pg.doBackup(url, true) })
        else app.toast(r.error)
    }
    function startRestore(url) {
        var i = backup.inspect(url)
        if (!i.ok) { app.toast(i.error); return }
        var name = url.toString().split("/").pop()
        app.ask(qsTr("Restore backup?"), name, qsTr("This replaces current playlists, favorites, overrides,\nand settings. Your music files are not affected."), qsTr("Restore backup"),
                function () { var r = backup.restore(url); app.toast(r.ok ? qsTr("Backup restored") : r.error) }, qsTr("Create a fresh backup first to keep current changes."))
    }
    Component.onCompleted: refreshCache()
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    FolderPickerDialog { id: picker }
    DuplicatesDialog { id: dups }
    Timer { interval: 1000; running: true; onTriggered: picker.show() }
    FileDialog { id: saveDlg; fileMode: FileDialog.SaveFile; defaultSuffix: "cadbak"; nameFilters: [qsTr("Cadence backup (*.cadbak)")]; onAccepted: pg.doBackup(selectedFile.toString(), false) }
    FileDialog { id: openDlg; nameFilters: [qsTr("Cadence backup (*.cadbak)")]; onAccepted: pg.startRestore(selectedFile.toString()) }

    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Music Library"); subtitle: qsTr("Choose where Cadence looks for your music.") }

        PrefCard {
            heading: qsTr("Music folders")
            PrefRow { visible: scanner.folders.length === 0; first: true; title: qsTr("No folders yet"); description: qsTr("Add a folder to start building your library.") }
            Repeater {
                model: scanner.folders
                delegate: PrefRow {
                    id: fr
                    required property int index
                    required property string modelData
                    first: index === 0
                    title: modelData.split("/").pop() || modelData
                    description: modelData + " · " + qsTr("%1 tracks").arg(scanner.folderTracks(modelData))
                    ActionButton {
                        implicitHeight: 36; text: qsTr("Remove folder")
                        onClicked: pg.app.ask(qsTr("Remove music folder?"), fr.modelData,
                            qsTr("Remove %1 tracks from your library index.\nOriginal music files will stay on your drive.").arg(scanner.folderTracks(fr.modelData)), qsTr("Remove folder"),
                            function () { scanner.removeFolder(fr.modelData) }, qsTr("Playlists may show unavailable tracks."))
                    }
                }
            }
            Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 4; spacing: 12
                ActionButton { primary: true; implicitHeight: 40; text: "+  " + qsTr("Add folder"); onClicked: picker.show() }
                ActionButton { implicitHeight: 36; text: scanner.scanning ? qsTr("Scanning…") : qsTr("Rescan library"); enabled: scanner.folders.length > 0 && !scanner.scanning; onClicked: scanner.rescanAll() }
                ActionButton { visible: scanner.scanning; implicitHeight: 36; text: qsTr("Cancel scan"); onClicked: scanner.cancel() }
                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted; text: qsTr("%1 tracks").arg(scanner.stats.songs || 0) + " · " + scanner.lastScanText }
            }
            ProgressBar { visible: scanner.scanning; Layout.fillWidth: true; Layout.bottomMargin: 6; from: 0; to: Math.max(1, scanner.total); value: scanner.progress }
        }

        PrefCard {
            heading: qsTr("Scanning")
            PrefRow {
                first: true; title: qsTr("Automatic background scanning"); description: qsTr("Watch selected folders and scan when files change.")
                Toggle { checked: pg.s.flag("library/monitor"); onToggled: (v) => pg.s.set("library/monitor", v) }
            }
            PrefRow {
                title: qsTr("Scan at startup"); description: qsTr("Check your folders for changes every time Cadence starts.")
                Toggle { checked: pg.s.flag("library/scanOnStart"); onToggled: (v) => pg.s.set("library/scanOnStart", v) }
            }
            PrefRow {
                title: qsTr("Detect potential duplicates"); description: qsTr("Flag similar tracks for review. Nothing is ever deleted.")
                Toggle { checked: pg.s.flag("library/duplicates"); onToggled: (v) => pg.s.set("library/duplicates", v) }
            }
            PrefRow {
                visible: pg.s.flag("library/duplicates"); title: qsTr("Duplicate matching"); description: qsTr("How close the lengths of two tracks must be.")
                SelectBox { model: [{v: 1000, t: qsTr("Within 1 second")}, {v: 3000, t: qsTr("Within 3 seconds")}, {v: 5000, t: qsTr("Within 5 seconds")}]; value: pg.s.num("library/dupTolerance"); onPicked: (v) => pg.s.set("library/dupTolerance", v) }
            }
            PrefRow {
                visible: pg.s.flag("library/duplicates"); title: qsTr("Review duplicates"); description: qsTr("See suspected duplicates. Cadence never deletes or changes your files.")
                ActionButton { implicitHeight: 36; text: qsTr("Review duplicates"); onClicked: dups.show(pg.s.num("library/dupTolerance")) }
            }
        }

        PrefCard {
            heading: qsTr("Artwork and data")
            PrefRow {
                first: true; title: qsTr("Artwork cache"); description: qsTr("%1 can be safely removed.").arg(pg.mb(pg.cacheBytes))
                ActionButton {
                    implicitHeight: 36; text: qsTr("Clear cache")
                    onClicked: pg.app.ask(qsTr("Clear artwork cache?"), qsTr("%1 can be safely removed.").arg(pg.mb(pg.cacheBytes)),
                        qsTr("Cadence will recreate artwork previews as needed.\nMusic files and playlists are not affected."), qsTr("Clear cache"),
                        function () { scanner.clearArtworkCache(); pg.refreshCache() }, qsTr("This action cannot be undone."))
                }
            }
            PrefRow {
                title: qsTr("Backup"); description: qsTr("Library data, favorites, history, playlists, lyrics edits, queue and settings. Never your music files. Daily automatic copy in %1.").arg(backup.backupDir)
                ActionButton { implicitHeight: 36; text: qsTr("Create backup…"); onClicked: saveDlg.open() }
                ActionButton { implicitHeight: 36; text: qsTr("Restore backup…"); onClicked: openDlg.open() }
            }
            PrefRow {
                title: qsTr("Database"); description: qsTr("Check the library database for problems.")
                ActionButton { implicitHeight: 36; text: qsTr("Check database"); onClicked: { var r = backup.checkIntegrity(); pg.app.toast(r === "ok" ? qsTr("Database is healthy") : backup.recover()) } }
            }
            PrefRow {
                title: qsTr("Listening history"); description: qsTr("Clears play counts and recently played. Favorites are kept.")
                ActionButton { implicitHeight: 36; text: qsTr("Clear history…"); onClicked: pg.app.ask(qsTr("Clear listening history?"), "", qsTr("Play counts and recently played will be reset.\nFavorites and playlists are kept."), qsTr("Clear history"), function () { scanner.clearHistory() }, qsTr("This action cannot be undone.")) }
            }
        }
    }
}
