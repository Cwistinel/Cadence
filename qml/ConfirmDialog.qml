import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Title, a 14 px bold line, a muted body, and an optional accent-colored note.
DesignDialog {
    id: d
    property string message
    property string note
    property string accentNote
    property var cb
    function ask(heading, msg, body, primary, callback, accent) {
        title = heading; message = msg; note = body || ""; accentNote = accent || ""
        primaryText = primary; cb = callback || null
        open()
    }
    onAccepted: if (cb) cb()
    Label { visible: d.message !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: d.message; font.pixelSize: 14; font.weight: Font.Medium }
    Label { visible: d.note !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: d.note; font.pixelSize: 13; color: theme.muted; lineHeight: 1.25 }
    Label { visible: d.accentNote !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: d.accentNote; font.pixelSize: 12; color: theme.accent }
}
