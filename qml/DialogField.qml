import QtQuick
import QtQuick.Controls

Rectangle {
    id: f
    property alias text: input.text
    property alias placeholder: input.placeholderText
    signal accepted()
    function focusInput() { input.forceActiveFocus(); input.selectAll() }
    implicitHeight: 44; radius: 7; color: theme.side
    border.width: 1; border.color: input.activeFocus ? theme.accent : theme.line
    TextField {
        id: input
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
        background: null; leftPadding: 0; rightPadding: 0
        font.pixelSize: 14; color: theme.text; placeholderTextColor: theme.muted; selectByMouse: true
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: f.accepted()
    }
}