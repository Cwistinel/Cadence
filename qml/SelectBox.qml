import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Figma select: 184×36, opens a list of {v, t} options (scrolls when long).
Rectangle {
    id: s
    property var model: []
    property var value
    property string hint: ""
    signal picked(var v)
    readonly property string currentText: { for (var i = 0; i < model.length; ++i) if (String(model[i].v) === String(value)) return model[i].t; return "" }
    implicitWidth: 184; implicitHeight: 36; radius: 7; color: theme.side
    border.width: 1; border.color: pop.opened || ma.containsMouse ? theme.accent : theme.line
    opacity: enabled ? 1 : 0.45
    Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 36; elide: Text.ElideRight; text: s.currentText; font.pixelSize: 13; font.weight: Font.Medium }
    Label { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; font.pixelSize: 13; color: theme.muted }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.opened ? pop.close() : pop.open() }
    Popup {
        id: pop
        x: s.width - width; y: s.height + 4
        width: Math.max(s.width, 208); padding: 8
        height: Math.min(list.contentHeight + 16 + (s.hint !== "" ? 26 : 0), 340)
        background: Rectangle { color: theme.panel; border.color: theme.line; border.width: 1; radius: 9 }
        contentItem: ColumnLayout {
            spacing: 6
            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: s.model; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: it
                    required property var modelData
                    readonly property bool on: String(modelData.v) === String(s.value)
                    width: ListView.view ? ListView.view.width : 0; height: 40; radius: 6
                    color: on ? theme.tint : ima.containsMouse ? Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.05) : "transparent"
                    Label { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44; elide: Text.ElideRight; text: it.modelData.t; font.pixelSize: 13; font.weight: Font.Medium; color: it.on ? theme.accent : theme.text }
                    Label { visible: it.on; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "✓"; color: theme.accent }
                    MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { s.picked(it.modelData.v); pop.close() } }
                }
            }
            Label { visible: s.hint !== ""; Layout.leftMargin: 6; text: s.hint; font.pixelSize: 11; color: theme.muted }
        }
    }
}
