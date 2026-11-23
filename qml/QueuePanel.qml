import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Panel {
    id: q
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 10; spacing: 6
        RowLayout {
            Label { text: qsTr("Queue") + " (" + pc.queue.count + ")"; font.bold: true; Layout.fillWidth: true }
            Button { text: qsTr("Clear"); enabled: pc.queue.count > 0; onClicked: pc.clearQueue() }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: pc.queue
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                id: row
                required property int index
                required property var trackId
                required property string title
                required property string artist
                required property var durationMs
                required property bool isCurrent
                width: ListView.view.width; height: 48; radius: 6
                z: handle.Drag.active ? 5 : 0
                color: dz.containsDrag ? alpha(theme.accent, 0.35) : isCurrent ? alpha(theme.accent, 0.18) : "transparent"
                DropArea { id: dz; anchors.fill: parent; keys: ["queue"]; onDropped: (d) => pc.moveTrack(d.source.srcIndex, row.index) }
                MouseArea { anchors.fill: parent; onDoubleClicked: pc.playIndex(row.index) }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 30; anchors.rightMargin: 4; spacing: 6
                    Cover { Layout.preferredWidth: 34; Layout.preferredHeight: 34; trackId: row.trackId; px: 80 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; text: row.title; font.bold: row.isCurrent; color: row.isCurrent ? theme.accent : theme.text }
                        Label { Layout.fillWidth: true; elide: Text.ElideRight; text: row.artist; font.pixelSize: 11; color: theme.subtext }
                    }
                    Label { text: q.fmt(row.durationMs); font.pixelSize: 11; color: theme.subtext }
                    IconButton { size: 26; glyph: "✕"; color: theme.subtext; tip: qsTr("Remove"); onClicked: pc.removeAt(row.index) }
                }
                Item {   // drag handle: reorder
                    id: handle
                    property int srcIndex: row.index
                    x: 2; y: 0; width: 26; height: row.height
                    Drag.active: hma.drag.active
                    Drag.keys: ["queue"]
                    Label { anchors.centerIn: parent; text: "≡"; color: theme.subtext; font.pixelSize: 18 }
                    MouseArea { id: hma; anchors.fill: parent; drag.target: handle; drag.axis: Drag.YAxis; onReleased: { handle.Drag.drop(); handle.x = 2; handle.y = 0 } }
                }
            }
        }
        Label { visible: pc.queue.count === 0; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: theme.subtext; text: qsTr("The queue is empty. Drag songs here or use “Add to queue”.") }
    }
    DropArea { anchors.fill: parent; keys: ["track"]; z: -1; onDropped: (d) => pc.enqueue(d.source.ids()) }
}