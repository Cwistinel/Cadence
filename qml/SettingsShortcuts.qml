import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    readonly property var app: Window.window
    readonly property var defaults: ["keys/playPause", "keys/next", "keys/prev", "keys/volUp", "keys/volDown", "keys/lyrics", "keys/queue"]
    ShortcutDialog { id: dlg; s: pg.s }
    Timer { interval: 1000; running: true; onTriggered: dlg.show(pg.s.shortcutRows[3]) }
    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Keyboard Shortcuts"); subtitle: qsTr("Make the keys feel familiar.") }
        PrefCard {
            Repeater {
                model: pg.s.shortcutRows
                delegate: PrefRow {
                    id: sr
                    required property int index
                    required property var modelData
                    first: index === 0
                    title: modelData.t
                    Rectangle {
                        implicitWidth: kc.implicitWidth + 24; implicitHeight: 30; radius: 6; color: theme.side; border.width: 1; border.color: theme.line
                        Label { id: kc; anchors.centerIn: parent; font.pixelSize: 12; font.weight: Font.Medium
                                text: sr.modelData.keys.length === 2 ? pg.s.display(pg.s.txt(sr.modelData.keys[0])) + " / " + pg.s.display(pg.s.txt(sr.modelData.keys[1])) : pg.s.display(pg.s.txt(sr.modelData.keys[0])) }
                    }
                    ActionButton { implicitHeight: 36; text: qsTr("Edit"); onClicked: dlg.show(sr.modelData) }
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 4; spacing: 12
                ActionButton {
                    implicitHeight: 36; text: qsTr("Restore defaults")
                    onClicked: pg.app.ask(qsTr("Restore default shortcuts?"), qsTr("Replace your custom key bindings?"),
                        qsTr("Playback shortcuts will return to their defaults.\nOther settings will not change."), qsTr("Restore defaults"),
                        function () { for (var i = 0; i < pg.defaults.length; ++i) pg.s.set(pg.defaults[i], pg.s.defs[pg.defaults[i]]) }, qsTr("You can customize them again any time."))
                }
                Label { Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: theme.muted
                        text: qsTr("Seek (← →), mute (M), favorite (F), mini-player (Ctrl M), undo (Ctrl Z), search (Ctrl K) and select all (Ctrl A) keys are fixed. Media keys follow Notifications & Desktop.") }
            }
        }
    }
}
