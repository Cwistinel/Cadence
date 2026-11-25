import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property string message
    property string note
    property var cb
    function ask(heading, msg, noteText, primary, callback) { title = heading; message = msg; note = noteText; primaryText = primary; cb = callback; open() }
    onAccepted: if (cb) cb()
    Label { visible: d.message !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: d.message; font.pixelSize: 15 }
    Label { visible: d.note !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: d.note; font.pixelSize: 13; color: theme.muted }
}