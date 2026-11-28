import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesignDialog {
    id: d
    property var s                          // the SettingsView (draft API)
    property var action: ({})               // {t, keys: [...]}
    property string pending: ""
    property bool cleared: false
    property string problem: ""
    readonly property var fixedKeys: ["Left", "Right", "M", "F", "Ctrl+M", "Ctrl+Z", "Ctrl+K", "Ctrl+A", "Media Play", "Media Pause", "Media Stop", "Media Next", "Media Previous"]
    title: qsTr("Edit shortcut")
    primaryText: qsTr("Save shortcut")
    primaryEnabled: (pending !== "" || cleared) && problem === ""
    function show(a) { action = a; pending = ""; cleared = false; problem = ""; open() }
    function usedBy(seq) {
        if (fixedKeys.indexOf(seq) >= 0) return qsTr("a fixed shortcut")
        var rows = s.shortcutRows
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i].keys[0] === action.keys[0]) continue
            for (var j = 0; j < rows[i].keys.length; ++j) if (s.txt(rows[i].keys[j]) === seq) return rows[i].t
        }
        return ""
    }
    function seqFor(k) { return k === "volDown" ? pending.replace(/Up$/, "Down") : pending }
    onOpened: capture.forceActiveFocus()
    onAccepted: {
        if (action.keys.length === 2) {          // volume: the pressed key is Up or Down; the other one follows with the same modifiers
            var base = cleared ? "" : pending.replace(/(Up|Down)$/, "")
            s.set(action.keys[0], base === "" ? "" : base + "Up"); s.set(action.keys[1], base === "" ? "" : base + "Down")
        } else s.set(action.keys[0], cleared ? "" : pending)
    }

    Label { text: d.action.t || ""; font.pixelSize: 12; color: theme.muted }
    Rectangle {
        id: capture
        Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 7; color: theme.side
        border.width: 1; border.color: activeFocus ? theme.accent : theme.line
        focus: true
        Keys.onPressed: (e) => {
            e.accepted = true
            if (e.key === Qt.Key_Escape) { d.close(); return }
            if (e.key === Qt.Key_Backspace) { d.pending = ""; d.cleared = true; d.problem = ""; return }
            var seq = settings.keyString(e.key, e.modifiers)
            if (seq === "") return
            if (d.action.keys.length === 2 && !/(Up|Down)$/.test(seq)) { d.problem = qsTr("Volume needs an Up or Down arrow key."); d.pending = ""; return }
            d.cleared = false; d.pending = seq
            var other = d.usedBy(d.action.keys.length === 2 ? seq.replace(/Down$/, "Up") : seq)
            d.problem = other !== "" ? qsTr("Already used by %1.").arg(other) : ""
        }
        Label {
            x: 12; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 14
            color: d.pending !== "" || d.cleared ? theme.text : theme.muted
            text: d.cleared ? qsTr("No shortcut") : d.pending !== "" ? d.s.display(d.pending) : qsTr("Press a key combination…")
        }
    }
    Label { Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: d.problem !== "" ? theme.accent : theme.muted
            text: d.problem !== "" ? d.problem : qsTr("Escape cancels · Backspace clears the binding.") }
}
