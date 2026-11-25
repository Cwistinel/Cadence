import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

DesignDialog {
    id: d
    property int plId: 0
    property var picked: ({})
    readonly property int n: Object.keys(picked).length
    title: qsTr("Add songs to playlist")
    primaryText: n === 1 ? qsTr("Add 1 song") : n > 1 ? qsTr("Add %1 songs").arg(n) : qsTr("Add songs")
    primaryEnabled: n > 0
    function show(id) { plId = id; picked = ({}); field.text = ""; open() }
    onOpened: field.focusInput()
    onAccepted: playlists.addTracks(plId, Object.keys(picked).map(Number))

    DialogField { id: field; Layout.fillWidth: true; placeholder: qsTr("Search your library") }
    ListView {
        id: list
        Layout.fillWidth: true; Layout.preferredHeight: 190
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        onContentYChanged: if (contentHeight - contentY - height < 300) lm.loadMore()
        model: LibraryModel { id: lm; mode: "songs"; sort: "title"; filters: field.text ? ({text: field.text}) : ({}) }
        delegate: Rectangle {
            id: row
            required property int index
            required property var trackId
            required property string title
            required property string artist
            readonly property bool on: !!d.picked[trackId]
            width: ListView.view ? ListView.view.width : 0; height: 38; radius: 6
            color: ma.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05) : "transparent"
            Label { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 16; elide: Text.ElideRight; font.pixelSize: 14
                    color: row.on ? theme.accent : theme.text; text: (row.on ? "☑" : "☐") + "  " + row.title + " · " + row.artist }
            MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { var p = Object.assign({}, d.picked); if (row.on) delete p[row.trackId]; else p[row.trackId] = true; d.picked = p }
            }
        }
    }
    Label { text: d.n === 1 ? qsTr("1 song selected") : qsTr("%1 songs selected").arg(d.n); font.pixelSize: 12; color: theme.muted }
}