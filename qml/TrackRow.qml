import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Figma "Track": 53 px row, 7 px radius. Used as a delegate of a songs-mode LibraryModel.
Rectangle {
    id: r
    required property int index
    required property var trackId
    required property string title
    required property string artist
    required property string album
    required property var durationMs
    required property bool favorite
    required property int extra
    property int number: index + 1
    property bool compact: false
    property bool playing: false
    property bool selected: false
    property bool showAlbum: true
    property var dragIds: [trackId]
    signal rowClicked(var mouse)
    signal playRequested()
    signal menuRequested()
    signal favoriteToggled()
    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    height: compact ? 40 : 53
    radius: 7
    color: playing ? theme.tint : selected ? a(theme.accent, 0.18) : ma.containsMouse ? a(theme.text, 0.04) : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => { if (m.button === Qt.RightButton) r.menuRequested(); else r.rowClicked(m) }
        onDoubleClicked: r.playRequested()
    }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 16; spacing: 12
        Label {
            Layout.preferredWidth: 22; font.pixelSize: 12; color: r.playing ? theme.accent : theme.muted
            text: r.playing ? (pc.playing ? "Ⅱ" : "▶") : (r.number < 10 ? "0" + r.number : r.number)
        }
        Cover { visible: !r.compact; Layout.preferredWidth: 36; Layout.preferredHeight: 36; rpx: 9; trackId: r.trackId; px: 96 }
        ColumnLayout {
            Layout.fillWidth: true; Layout.preferredWidth: 300; spacing: 0
            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; color: r.playing ? theme.accent : theme.text; text: r.title || qsTr("(Unknown)") }
            Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: theme.muted; text: r.artist }
        }
        Label { visible: r.showAlbum; Layout.fillWidth: true; Layout.preferredWidth: 521; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted; text: r.album }
        Label { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font.pixelSize: 12; color: theme.muted; text: r.fmt(r.durationMs) }
        Label {
            Layout.leftMargin: 14; text: r.favorite ? "♥" : "♡"; font.pixelSize: 19; color: r.favorite ? theme.accent : theme.muted
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: r.favoriteToggled() }
        }
        Label {
            Layout.leftMargin: 14; text: "···"; font.pixelSize: 20; color: theme.muted
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: r.menuRequested() }
        }
    }
    Item {   // drag handle over the number column: drop on the queue or on a sidebar playlist
        id: grip
        x: 0; y: 0; width: 34; height: r.height
        z: Drag.active ? 10 : 1
        Drag.active: gma.drag.active
        Drag.keys: ["track"]
        function ids() { return r.dragIds }
        MouseArea {
            id: gma; anchors.fill: parent; drag.target: grip; cursorShape: Qt.OpenHandCursor
            onClicked: (m) => r.rowClicked(m)
            onDoubleClicked: r.playRequested()
            onReleased: { grip.Drag.drop(); grip.x = 0; grip.y = 0 }
        }
    }
}