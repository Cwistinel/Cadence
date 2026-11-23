import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: sv
    readonly property var app: Window.window
    function doBackup(url, over) {
        var r = backup.create(url, over)
        if (r.ok) app.toast(qsTr("Backup saved"))
        else if (r.error === "exists") app.confirm(qsTr("The file already exists. Overwrite it?"), function () { sv.doBackup(url, true) })
        else app.toast(r.error)
    }
    function startRestore(url) {
        var i = backup.inspect(url)
        if (!i.ok) { app.toast(i.error); return }
        app.confirm(qsTr("Restore this backup?\nCreated: %1\n%2 tracks, %3 playlists.\n\nYour current data is replaced. A safety copy is saved first.").arg(i.created).arg(i.tracks).arg(i.playlists),
                    function () { var r = backup.restore(url); app.toast(r.ok ? qsTr("Backup restored") : r.error) })
    }

    component Section: Label { Layout.topMargin: 14; font.pixelSize: 18; font.bold: true; color: theme.accent }
    component SwitchRow: RowLayout {
        id: sr
        property string key
        property bool def: false
        property string label
        Layout.fillWidth: true
        Label { text: sr.label; Layout.fillWidth: true }
        Switch { checked: (settings.revision, settings.flag(sr.key, sr.def)); onToggled: settings.setValue(sr.key, checked) }
    }
    component ComboRow: RowLayout {
        id: cr
        property string key
        property string def
        property string label
        property var options: []
        Layout.fillWidth: true
        Label { text: cr.label; Layout.fillWidth: true }
        ComboBox { textRole: "t"; valueRole: "v"; model: cr.options; currentIndex: (settings.revision, Math.max(0, indexOfValue(settings.text(cr.key, cr.def)))); onActivated: settings.setValue(cr.key, currentValue) }
    }

    FolderDialog { id: fd; onAccepted: scanner.addFolder(selectedFolder.toString()) }
    FileDialog { id: saveDlg; fileMode: FileDialog.SaveFile; defaultSuffix: "cadbak"; nameFilters: [qsTr("Cadence backup (*.cadbak)")]; onAccepted: sv.doBackup(selectedFile.toString(), false) }
    FileDialog { id: openDlg; nameFilters: [qsTr("Cadence backup (*.cadbak)")]; onAccepted: sv.startRestore(selectedFile.toString()) }
    Dialog {
        id: dupDlg
        property var groups: []
        parent: Overlay.overlay; anchors.centerIn: parent; modal: true
        width: Math.min(parent.width - 40, 760); height: Math.min(parent.height - 40, 560)
        title: qsTr("Possible duplicates"); standardButtons: Dialog.Close
        ColumnLayout {
            anchors.fill: parent
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.subtext; text: dupDlg.groups.length === 0 ? qsTr("No duplicates found.") : qsTr("Review only. Cadence never deletes or changes your files.") }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: dupDlg.groups; spacing: 10
                ScrollBar.vertical: ScrollBar {}
                delegate: Column {
                    id: gr
                    required property var modelData
                    width: ListView.view.width; spacing: 2
                    Label { text: gr.modelData.reason; font.bold: true; color: theme.accent }
                    Repeater {
                        model: gr.modelData.tracks
                        Label { required property var modelData; width: gr.width; elide: Text.ElideMiddle; font.pixelSize: 12; text: modelData.artist + " — " + modelData.title + "   " + modelData.path }
                    }
                }
            }
        }
    }

    ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            x: 20; width: scroll.availableWidth - 40; spacing: 8

            Section { text: qsTr("Library") }
            Repeater {
                model: scanner.folders
                RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; elide: Text.ElideMiddle; text: modelData }
                    Button { text: qsTr("Rescan"); onClicked: scanner.rescan(modelData) }
                    Button { text: qsTr("Remove"); onClicked: sv.app.confirm(qsTr("Remove this folder from the library? Files are not touched; favorites and playlists are kept."), function () { scanner.removeFolder(modelData) }) }
                }
            }
            RowLayout {
                Button { text: qsTr("Add folder…"); onClicked: fd.open() }
                Button { text: qsTr("Rescan all"); enabled: scanner.folders.length > 0 && !scanner.scanning; onClicked: scanner.rescanAll() }
                Button { text: qsTr("Cancel scan"); visible: scanner.scanning; onClicked: scanner.cancel() }
                Button { text: qsTr("Find duplicates"); onClicked: { dupDlg.groups = scanner.duplicates(); dupDlg.open() } }
            }
            ProgressBar { visible: scanner.scanning; Layout.fillWidth: true; from: 0; to: Math.max(1, scanner.total); value: scanner.progress }
            SwitchRow { label: qsTr("Watch folders for changes"); key: "library/monitor"; def: true }
            SwitchRow { label: qsTr("Rescan at startup"); key: "library/scanOnStart"; def: true }
            Button { text: qsTr("Clear listening history…"); onClicked: sv.app.confirm(qsTr("Clear play counts and recently played? Favorites are kept."), function () { scanner.clearHistory() }) }

            Section { text: qsTr("Appearance & desktop") }
            ComboRow { label: qsTr("Theme"); key: "ui/theme"; def: "auto"; options: [{v: "auto", t: qsTr("Automatic (album art)")}, {v: "light", t: qsTr("Light")}, {v: "dark", t: qsTr("Dark")}] }
            SwitchRow { label: qsTr("Close to tray (keeps playing)"); key: "ui/closeToTray"; def: false; enabled: desktop.trayAvailable }
            SwitchRow { label: qsTr("Notify on track change"); key: "ui/notifications"; def: true }

            Section { text: qsTr("Playback") }
            SwitchRow { label: qsTr("Gapless playback"); key: "audio/gapless"; def: true }
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: qsTr("Crossfade") + ": " + ((settings.revision, settings.number("audio/crossfadeMs", 0)) === 0 ? qsTr("off") : ((settings.number("audio/crossfadeMs", 0) / 1000).toFixed(1) + " s")) }
                ThemedSlider { Layout.preferredWidth: 220; from: 0; to: 12000; stepSize: 500; bound: (settings.revision, settings.number("audio/crossfadeMs", 0)); onMoved: settings.setValue("audio/crossfadeMs", Math.round(value)) }
            }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.subtext; font.pixelSize: 12; text: qsTr("Crossfade is separate from gapless. When it is on, fades handle track changes; tracks too short to fade stay gapless.") }
            ComboRow { label: qsTr("ReplayGain"); key: "audio/replayGain"; def: "off"; options: [{v: "off", t: qsTr("Off")}, {v: "track", t: qsTr("Track")}, {v: "album", t: qsTr("Album")}] }
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: qsTr("Speed") + ": " + pc.speed.toFixed(2) + "×" }
                ThemedSlider { Layout.preferredWidth: 220; from: 0.5; to: 2.0; stepSize: 0.05; bound: pc.speed; onMoved: pc.setSpeed(value) }
                Button { text: "1×"; onClicked: pc.setSpeed(1.0) }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("Output device"); Layout.fillWidth: true }
                ComboBox {
                    Layout.preferredWidth: 280
                    model: [qsTr("System default")].concat(pc.devices)
                    currentIndex: Math.max(0, pc.device === "" ? 0 : pc.devices.indexOf(pc.device) + 1)
                    onActivated: pc.setDevice(currentIndex === 0 ? "" : currentText)
                }
            }

            Section { text: qsTr("Backup & recovery") }
            Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.subtext; font.pixelSize: 12; text: qsTr("A backup holds your library data, favorites, history, playlists, lyrics and metadata edits, queue and settings. It never contains music files. Backups can be saved to a USB drive. An automatic daily backup is kept in %1.").arg(backup.backupDir) }
            RowLayout {
                Button { text: qsTr("Create backup…"); onClicked: saveDlg.open() }
                Button { text: qsTr("Restore backup…"); onClicked: openDlg.open() }
                Button {
                    text: qsTr("Check database")
                    onClicked: { var r = backup.checkIntegrity(); sv.app.toast(r === "ok" ? qsTr("Database is healthy") : backup.recover()) }
                }
            }

            Section { text: qsTr("Keyboard shortcuts") }
            Label {
                Layout.fillWidth: true; wrapMode: Text.Wrap; lineHeight: 1.3
                text: qsTr("Space  play / pause\n← / →  seek 5 s back / forward\nCtrl+← / Ctrl+→  previous / next track\nCtrl+↑ / Ctrl+↓  volume up / down\nM  mute\nQ  show / hide queue\nL  show / hide lyrics\nF  favorite the current track\nCtrl+M  mini-player\nCtrl+Z  undo\nCtrl+A  select all songs in the list\nMedia keys  play, pause, stop, previous, next (also from headsets and the desktop's media controls)")
            }
            Item { Layout.preferredHeight: 30 }
        }
    }
}