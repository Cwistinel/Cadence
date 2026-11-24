import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Figma "Page heading": 30 px title, 12 px subtitle, 290×40 search field with a Ctrl K hint.
Item {
    id: h
    property string title
    property string subtitle
    property bool searchable: true
    readonly property string query: field.text
    signal submitted(string text)
    implicitHeight: 70
    function focusSearch() { field.forceActiveFocus(); field.selectAll() }
    function setQuery(t) { field.text = t }
    RowLayout {
        anchors.fill: parent; spacing: 12
        ColumnLayout {
            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 3
            Label { Layout.fillWidth: true; elide: Text.ElideRight; text: h.title; font.pixelSize: 30; font.weight: Font.DemiBold }
            Label { Layout.fillWidth: true; elide: Text.ElideRight; text: h.subtitle; font.pixelSize: 12; color: theme.muted }
        }
        Rectangle {
            visible: h.searchable
            Layout.preferredWidth: 290; Layout.preferredHeight: 40; Layout.alignment: Qt.AlignVCenter
            radius: 8; color: theme.panel
            border.width: field.activeFocus ? 2 : 1; border.color: field.activeFocus ? theme.accent : theme.line
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                Label { text: "⌕"; font.pixelSize: 23; color: theme.muted }
                TextField {
                    id: field
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search your music"); placeholderTextColor: theme.muted
                    font.pixelSize: 12; color: theme.text; selectByMouse: true
                    background: null; leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                    onAccepted: h.submitted(text)
                }
                Label { visible: field.text === ""; text: "Ctrl K"; font.pixelSize: 10; color: theme.muted }
            }
        }
    }
    Shortcut { sequence: "Ctrl+K"; enabled: h.visible && h.searchable; onActivated: h.focusSearch() }
}