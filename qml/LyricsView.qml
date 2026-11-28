import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Item {
    id: lv
    readonly property var app: Window.window
    readonly property bool compact: width - 64 < 1000
    readonly property real idW: compact ? 190 : 224
    readonly property real artW: compact ? 180 : 224
    property bool plainChosen: false          // Plain selected in the display switch
    property bool paused: false               // following paused by manual scrolling
    property bool auto: false                 // true while Cadence itself is scrolling to the current line
    readonly property bool followSetting: (settings.revision, settings.flag("lyrics/follow", true))
    readonly property string fam: (settings.revision, settings.text("lyrics/fontFamily", ""))
    readonly property int fsz: (settings.revision, settings.number("lyrics/fontSize", 24))
    readonly property int wgt: (settings.revision, settings.number("lyrics/fontWeight", 400))
    readonly property string align: (settings.revision, settings.text("lyrics/align", "center"))
    readonly property string shown: !lyrics.hasLyrics || (!lyrics.synced && !(settings.revision, settings.flag("lyrics/plainFallback", true))) ? "none" : (plainChosen || !lyrics.synced) ? "plain" : "synced"
    readonly property bool following: followSetting && !paused
    readonly property string sourceText: lyrics.hasLyrics ? (lyrics.synced ? qsTr("Synchronized") : qsTr("Plain text")) + " · " + lyrics.sourceName : qsTr("No lyrics loaded")
    readonly property string badge: !lyrics.hasLyrics ? qsTr("LRC & TXT supported") : lyrics.synced ? qsTr("LRC · Synchronized lyrics") : qsTr("TXT · Untimed lyrics")

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    Connections { target: lyrics; function onLyricsChanged() { lv.plainChosen = settings.text("lyrics/defaultMode", "synced") === "plain"; lv.paused = false } function onCurrentLineChanged() { lv.auto = true; autoTimer.restart() } }
    Timer { id: autoTimer; interval: 600; onTriggered: lv.auto = false }
    LoadLyricsDialog { id: loadDlg; onBrowse: fd.open(); onFailed: lv.app.toast(qsTr("Could not read that lyrics file")) }
    FileDialog {
        id: fd
        nameFilters: [qsTr("Lyrics (*.lrc *.txt)")]
        onAccepted: { if (!lyrics.loadFile(selectedFile.toString())) lv.app.toast(qsTr("Could not read that lyrics file")) }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20

        ColumnLayout {   // header
            Layout.fillWidth: true; spacing: 14
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 38; spacing: 12
                ActionButton { implicitHeight: 36; text: "← " + qsTr("Now playing"); onClicked: lv.app.showPage("now") }
                Item { Layout.fillWidth: true }
                Rectangle {   // display mode
                    Layout.preferredWidth: 254; Layout.preferredHeight: 38; radius: 8; color: theme.panel; border.width: 1; border.color: theme.line
                    Row {
                        x: 3; y: 3; spacing: 4
                        Rectangle {
                            width: 150; height: 32; radius: 6; opacity: lyrics.synced || !lyrics.hasLyrics ? 1 : 0.4
                            color: lv.shown !== "plain" ? theme.tint : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Label { anchors.centerIn: parent; text: qsTr("Synchronized"); font.pixelSize: 13; font.weight: Font.Medium; color: lv.shown !== "plain" ? theme.accent : theme.muted }
                            MouseArea { anchors.fill: parent; enabled: lyrics.synced; cursorShape: Qt.PointingHandCursor; onClicked: lv.plainChosen = false }
                        }
                        Rectangle {
                            width: 90; height: 32; radius: 6; opacity: lyrics.hasLyrics ? 1 : 0.4
                            color: lv.shown === "plain" ? theme.tint : "transparent"
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Label { anchors.centerIn: parent; text: qsTr("Plain"); font.pixelSize: 13; font.weight: Font.Medium; color: lv.shown === "plain" ? theme.accent : theme.muted }
                            MouseArea { anchors.fill: parent; enabled: lyrics.hasLyrics; cursorShape: Qt.PointingHandCursor; onClicked: lv.plainChosen = true }
                        }
                    }
                }
                ActionButton { implicitHeight: 36; text: qsTr("Load lyrics…"); enabled: pc.hasTrack; onClicked: loadDlg.show() }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 12
                Label { Layout.fillWidth: true; text: qsTr("Lyrics"); font.pixelSize: 30; font.weight: Font.DemiBold }
                Label { Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 8; font.pixelSize: 12; color: theme.muted; text: lv.sourceText }
            }
        }

        RowLayout {   // track identity + lyric lines
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 24

            Column {
                Layout.preferredWidth: lv.idW; Layout.alignment: Qt.AlignTop; spacing: 14
                Cover { width: lv.artW; height: lv.artW; rpx: 9; trackId: pc.track.id || 0; px: 450 }
                Column {
                    width: parent.width; spacing: 6
                    Label { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: 24; font.weight: Font.DemiBold; text: pc.hasTrack ? pc.track.title : qsTr("Nothing playing") }
                    Label { width: parent.width; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.Medium; color: theme.muted; text: pc.hasTrack ? pc.track.artist : "" }
                    Label { width: parent.width; elide: Text.ElideRight; font.pixelSize: 13; color: theme.muted; text: pc.hasTrack && pc.track.album ? pc.track.album + (pc.track.year > 0 ? " · " + pc.track.year : "") : "" }
                }
                Label { font.pixelSize: 11; color: lyrics.hasLyrics ? theme.accent : theme.muted; text: lv.badge }
            }

            Item {   // lyrics viewport
                Layout.fillWidth: true; Layout.fillHeight: true
                ListView {
                    id: list
                    anchors.fill: parent
                    visible: lv.shown !== "none"
                    clip: true; model: lyrics.lines; boundsBehavior: Flickable.StopAtBounds
                    currentIndex: Math.max(0, lyrics.currentLine)
                    highlightRangeMode: lv.shown === "synced" && lv.following ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
                    preferredHighlightBegin: height / 2 - 32; preferredHighlightEnd: height / 2 + 32
                    highlightMoveDuration: 380
                    highlight: Item {}
                    header: Item { width: 1; height: lv.shown === "plain" ? 16 : 40 }
                    footer: Item { width: 1; height: 128 }
                    ScrollBar.vertical: ScrollBar {}
                    onMovingChanged: if (moving && !lv.auto && lv.shown === "synced" && lv.followSetting) lv.paused = true
                    delegate: Item {
                        id: ln
                        required property int index
                        required property var modelData
                        readonly property int dist: Math.abs(index - lyrics.currentLine)
                        readonly property bool active: lv.shown === "synced" && index === lyrics.currentLine
                        width: ListView.view ? ListView.view.width : 0
                        height: Math.max(64, lbl.implicitHeight + 24)
                        Label {
                            id: lbl
                            x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.Wrap
                            text: ln.modelData.text === "" ? " " : ln.modelData.text
                            horizontalAlignment: lv.align === "left" ? Text.AlignLeft : lv.align === "right" ? Text.AlignRight : Text.AlignHCenter
                            font.family: lv.fam || Qt.application.font.family
                            font.pixelSize: ln.active ? Math.round(lv.fsz * 4 / 3) : lv.fsz
                            font.weight: ln.active ? Font.DemiBold : lv.wgt
                            opacity: lv.shown === "plain" ? 0.62 : ln.active ? 1 : ln.dist === 1 ? 0.62 : 0.46
                            Behavior on opacity { NumberAnimation { duration: 220 } }
                            Behavior on font.pixelSize { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; enabled: lv.shown === "synced"; cursorShape: Qt.PointingHandCursor; onClicked: pc.seek(ln.modelData.ms + lyrics.offsetMs) }
                    }
                }
                Column {   // no lyrics for this song
                    visible: lv.shown === "none"
                    anchors.centerIn: parent; spacing: 18
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("No lyrics for this song yet."); font.pixelSize: 24; font.weight: Font.DemiBold }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Load an LRC or TXT file to follow along."); font.pixelSize: 14; color: theme.muted }
                    ActionButton { anchors.horizontalCenter: parent.horizontalCenter; primary: true; implicitHeight: 40; text: qsTr("Load lyrics file"); enabled: pc.hasTrack; onClicked: loadDlg.show() }
                }
            }
        }

        RowLayout {   // utility bar
            Layout.fillWidth: true; Layout.preferredHeight: 44; spacing: 12

            RowLayout {
                spacing: 12
                Rectangle {   // follow switch
                    visible: lv.shown === "synced" && !lv.paused
                    Layout.preferredWidth: 44; Layout.preferredHeight: 26; radius: 13
                    color: lv.followSetting ? theme.accent : theme.line
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Rectangle {
                        y: 3; width: 20; height: 20; radius: 10; color: lv.followSetting ? theme.onAccent : theme.muted
                        x: lv.followSetting ? 21 : 3
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.setValue("lyrics/follow", !lv.followSetting) }
                }
                Label { visible: lv.shown === "synced" && !lv.paused; font.pixelSize: 12; color: theme.muted; text: qsTr("Follow current line") }
                ActionButton { visible: lv.shown === "synced" && lv.paused; implicitHeight: 36; text: qsTr("Resume following"); onClicked: lv.paused = false }
                Label { visible: lv.shown === "synced" && lv.paused; font.pixelSize: 11; color: theme.muted; text: qsTr("Following paused") }
                Label { visible: lv.shown === "plain"; font.pixelSize: 12; color: theme.muted; text: qsTr("Scroll to read plain lyrics") }
                Label { visible: lv.shown === "none"; font.pixelSize: 12; color: theme.muted; text: qsTr("Load a local .lrc or .txt file") }
            }
            Item { Layout.fillWidth: true }
            RowLayout {   // timing
                spacing: 10; opacity: lv.shown === "synced" ? 1 : 0.45
                Label { text: qsTr("Timing"); font.pixelSize: 12; color: theme.muted }
                ActionButton { implicitHeight: 36; text: qsTr("−100 ms"); enabled: lv.shown === "synced"; onClicked: lyrics.adjustOffset(-100) }
                Row {
                    spacing: 2
                    Label { font.pixelSize: 13; font.weight: Font.Medium; text: (lyrics.offsetMs > 0 ? "+" : "") + lyrics.offsetMs }
                    Label { font.pixelSize: 12; color: theme.muted; text: qsTr("ms") }
                }
                ActionButton { implicitHeight: 36; text: qsTr("+100 ms"); enabled: lv.shown === "synced"; onClicked: lyrics.adjustOffset(100) }
            }
        }
    }
}
