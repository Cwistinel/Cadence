import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

Dialog {
    id: d
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: Math.min(parent.width - 40, 780); height: Math.min(parent.height - 40, 600)
    title: qsTr("Edit lyrics")
    standardButtons: Dialog.Save | Dialog.Cancel
    function edit() { ta.text = lyrics.rawText; open() }
    function stampLine() {   // writes the current playback position onto the line under the cursor
        var t = ta.text, p = ta.cursorPosition
        var s = t.lastIndexOf("\n", p - 1) + 1, e = t.indexOf("\n", p)
        if (e < 0) e = t.length
        var line = t.substring(s, e).replace(/^(\s*\[[^\]]*\])+\s*/, "")
        var stamped = lyrics.compose([{ms: pc.position, text: line}])
        ta.text = t.substring(0, s) + stamped + t.substring(e)
        ta.cursorPosition = s + stamped.length
    }
    onAccepted: lyrics.save(ta.text)
    FileDialog { id: fd; nameFilters: [qsTr("Lyrics (*.lrc *.txt)")]; onAccepted: { var t = lyrics.readFile(selectedFile.toString()); if (t !== "") ta.text = t } }
    ColumnLayout {
        anchors.fill: parent; spacing: 8
        Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.subtext; font.pixelSize: 12
            text: qsTr("Synced lines look like [01:23.45] text. Edits are saved inside Cadence; your .lrc file and audio are never changed.") }
        RowLayout {
            spacing: 6
            Button { text: qsTr("Import file…"); onClicked: fd.open() }
            Button { text: qsTr("Paste"); onClicked: ta.paste() }
            Button { text: qsTr("Stamp line at playback position"); onClicked: d.stampLine() }
            Item { Layout.fillWidth: true }
            Button { text: qsTr("Use original"); enabled: lyrics.source === "edited"; onClicked: { lyrics.removeEdit(); d.close() } }
        }
        RowLayout {
            spacing: 6
            Label { text: qsTr("Shift all timestamps") }
            SpinBox { id: delta; from: 0; to: 600000; stepSize: 100; value: 500; editable: true }
            Label { text: qsTr("ms") }
            Button { text: qsTr("Earlier"); onClicked: ta.text = lyrics.shift(ta.text, -delta.value) }
            Button { text: qsTr("Later"); onClicked: ta.text = lyrics.shift(ta.text, delta.value) }
            Label { color: theme.subtext; font.pixelSize: 12; text: qsTr("(shown here as a preview; Save to keep, Cancel to discard)") }
        }
        ScrollView {
            Layout.fillWidth: true; Layout.fillHeight: true
            TextArea { id: ta; wrapMode: TextArea.NoWrap; font.family: "monospace"; selectByMouse: true; placeholderText: qsTr("Paste lyrics here, or type them…") }
        }
    }
}