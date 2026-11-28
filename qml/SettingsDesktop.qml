import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    readonly property var app: Window.window
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    Timer { interval: 1000; running: true; onTriggered: pg.app.ask("Clear listening history?", "Play counts and recently played will be reset.", "Favorites and playlists are kept.", "Clear history", null, "This action cannot be undone.") }
    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Notifications & Desktop"); subtitle: qsTr("Quiet, useful, and easy to turn off.") }
        PrefCard {
            heading: qsTr("Notifications")
            PrefRow {
                first: true; title: qsTr("Desktop notifications"); description: qsTr("Show the song when it changes while Cadence is in the background.")
                Toggle { checked: pg.s.flag("ui/notifications"); onToggled: (v) => pg.s.set("ui/notifications", v) }
            }
            PrefRow {
                title: qsTr("Notification detail"); description: qsTr("How much to show.")
                SelectBox {
                    enabled: pg.s.flag("ui/notifications")
                    model: [{v: "title", t: qsTr("Title only")}, {v: "artist", t: qsTr("Title and artist")}, {v: "full", t: qsTr("Title, artist and album")}]
                    value: pg.s.txt("ui/notificationDetail"); onPicked: (v) => pg.s.set("ui/notificationDetail", v)
                }
            }
        }
        PrefCard {
            heading: qsTr("System tray and media keys")
            PrefRow {
                first: true; title: qsTr("System tray"); description: desktop.trayAvailable ? qsTr("Show a Cadence icon with play, previous and next.") : qsTr("Your desktop doesn’t provide a system tray.")
                Toggle { enabled: desktop.trayAvailable; checked: desktop.trayAvailable && pg.s.flag("ui/tray"); onToggled: (v) => pg.s.set("ui/tray", v) }
            }
            PrefRow {
                title: qsTr("Close to tray"); description: qsTr("Closing the window keeps music playing in the tray.")
                Toggle { enabled: desktop.trayAvailable && pg.s.flag("ui/tray"); checked: pg.s.flag("ui/closeToTray"); onToggled: (v) => pg.s.set("ui/closeToTray", v) }
            }
            PrefRow {
                title: qsTr("Media key controls"); description: qsTr("Respond to play, pause, previous and next keys.")
                Toggle { checked: pg.s.flag("ui/mediaKeys"); onToggled: (v) => pg.s.set("ui/mediaKeys", v) }
            }
        }
        PrefCard {
            heading: qsTr("About")
            PrefRow {
                first: true; title: qsTr("Open-source licenses"); description: qsTr("Cadence uses your Linux desktop’s notification and media-control services.")
                ActionButton {
                    implicitHeight: 36; text: qsTr("View licenses")
                    onClicked: pg.app.ask(qsTr("Open-source licenses"), qsTr("Libraries Cadence is built with"),
                        "Qt 6 · LGPL 3\nGStreamer · LGPL 2.1\nTagLib · LGPL 2.1 / MPL 1.1\nSQLite · Public domain\nInter · SIL Open Font License 1.1", qsTr("Done"), null,
                        qsTr("License texts ship with the installed packages."))
                }
            }
        }
    }
}
