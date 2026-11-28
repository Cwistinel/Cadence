import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: sv
    readonly property var app: Window.window
    property int cat: 0
    property var draft: ({})
    readonly property int changes: Object.keys(draft).length
    readonly property var cats: [
        {t: qsTr("Appearance"), src: "SettingsAppearance.qml"}, {t: qsTr("Music Library"), src: "SettingsLibrary.qml"}, {t: qsTr("Playback"), src: "SettingsPlayback.qml"},
        {t: qsTr("Audio"), src: "SettingsAudio.qml"}, {t: qsTr("Lyrics"), src: "SettingsLyrics.qml"}, {t: qsTr("Keyboard Shortcuts"), src: "SettingsShortcuts.qml"},
        {t: qsTr("Notifications & Desktop"), src: "SettingsDesktop.qml"}]
    readonly property var shortcutRows: [
        {t: qsTr("Play / pause"), keys: ["keys/playPause"]}, {t: qsTr("Next track"), keys: ["keys/next"]}, {t: qsTr("Previous track"), keys: ["keys/prev"]},
        {t: qsTr("Volume up / down"), keys: ["keys/volUp", "keys/volDown"]}, {t: qsTr("Toggle lyrics"), keys: ["keys/lyrics"]}, {t: qsTr("Show queue"), keys: ["keys/queue"]}]
    readonly property var defs: ({
        "ui/theme": "system", "ui/artColors": false, "ui/accent": "blue", "ui/density": "comfortable",
        "library/monitor": true, "library/scanOnStart": true, "library/duplicates": true, "library/dupTolerance": 3000,
        "audio/gapless": true, "audio/crossfadeMs": 0, "playback/shuffleStart": "last", "playback/repeatStart": "off", "audio/speed": 1.0,
        "playback/resume": true, "audio/replayGain": "off", "audio/device": "", "audio/bufferMs": 200, "audio/rememberVolume": true, "audio/maxVolume": 1.0,
        "lyrics/fontFamily": "", "lyrics/fontSize": 24, "lyrics/align": "center", "lyrics/follow": true, "lyrics/defaultMode": "synced", "lyrics/plainFallback": true,
        "keys/playPause": "Space", "keys/next": "Ctrl+Right", "keys/prev": "Ctrl+Left", "keys/volUp": "Ctrl+Up", "keys/volDown": "Ctrl+Down", "keys/lyrics": "Ctrl+L", "keys/queue": "Ctrl+Q",
        "ui/notifications": true, "ui/tray": true, "ui/closeToTray": false, "ui/mediaKeys": true, "ui/notificationDetail": "artist"})

    // Staged editing: controls read and write the draft; "Save changes" commits it to the real settings.
    function get(k) { var r = settings.revision; return draft.hasOwnProperty(k) ? draft[k] : settings.value(k, defs[k]) }
    function flag(k) { var v = get(k); return v === true || v === "true" }
    function num(k) { return Number(get(k)) }
    function txt(k) { return String(get(k)) }
    function set(k, v) {
        var d = Object.assign({}, draft)
        if (String(settings.value(k, defs[k])) === String(v)) delete d[k]; else d[k] = v
        draft = d
    }
    function reset() { draft = ({}) }
    function goCategory(i) { cat = i }
    function save() { for (var k in draft) settings.setValue(k, draft[k]); draft = ({}); app.toast(qsTr("Settings saved")) }
    function display(seq) { return seq === "" ? qsTr("None") : seq.replace(/\+/g, " ").replace("Right", "→").replace("Left", "←").replace("Up", "↑").replace("Down", "↓") }
    function loadPage() { page.setSource(cats[cat].src, {s: sv}) }
    onCatChanged: loadPage()
    Component.onCompleted: { loadPage(); cycle.start() }
    Timer { id: cycle; interval: 2500; repeat: true; onTriggered: sv.cat = (sv.cat + 1) % 7 }

    RowLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {   // settings navigation
            Layout.preferredWidth: 256; Layout.fillHeight: true; color: theme.side
            ColumnLayout {
                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 18; spacing: 6
                Label { Layout.bottomMargin: 10; text: "Cadence"; font.pixelSize: 24; font.weight: Font.DemiBold }
                ActionButton { implicitHeight: 36; text: "←  " + qsTr("Back to music"); onClicked: sv.app.showPage(sv.app.settingsBack) }
                Label { Layout.topMargin: 14; text: qsTr("Settings"); font.pixelSize: 18; font.weight: Font.DemiBold }
                Repeater {
                    model: sv.cats
                    delegate: Rectangle {
                        id: ci
                        required property int index
                        required property var modelData
                        readonly property bool on: sv.cat === index
                        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 7
                        color: on ? theme.tint : cma.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Label { x: 12; anchors.verticalCenter: parent.verticalCenter; text: ci.modelData.t; font.pixelSize: 13; font.weight: Font.Medium; color: ci.on ? theme.accent : theme.muted }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sv.cat = ci.index }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.leftMargin: 36; Layout.rightMargin: 36; Layout.topMargin: 26; Layout.bottomMargin: 14; spacing: 16
            Loader { id: page; Layout.fillWidth: true; Layout.fillHeight: true }
            Item {   // save bar
                Layout.fillWidth: true; Layout.preferredHeight: 62
                Rectangle { width: parent.width; height: 1; color: theme.line }
                RowLayout {
                    anchors.fill: parent; anchors.topMargin: 8; spacing: 12
                    Label {
                        Layout.fillWidth: true; font.pixelSize: 12; color: sv.changes > 0 ? theme.accent : theme.muted
                        text: sv.changes > 0 ? "●  " + (sv.changes === 1 ? qsTr("1 unsaved change") : qsTr("%1 unsaved changes").arg(sv.changes)) : "✓  " + qsTr("All changes saved locally")
                    }
                    ActionButton { implicitHeight: 36; text: qsTr("Reset changes"); enabled: sv.changes > 0; onClicked: sv.reset() }
                    ActionButton { implicitHeight: 40; primary: true; text: qsTr("Save changes"); enabled: sv.changes > 0; onClicked: sv.save() }
                }
            }
        }
    }
}
