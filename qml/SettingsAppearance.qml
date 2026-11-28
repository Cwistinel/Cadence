import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    readonly property string theme_: { var t = s.txt("ui/theme"); return t === "auto" ? "system" : t }
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Appearance"); subtitle: qsTr("Make Cadence feel at home on your desktop.") }

        PrefCard {
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: qsTr("Theme"); font.pixelSize: 16; font.weight: Font.Medium }
                Label { text: qsTr("Choose a base appearance"); font.pixelSize: 12; color: theme.muted }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 12; Layout.bottomMargin: 14; spacing: 14
                Repeater {
                    model: [{v: "light", t: qsTr("Light")}, {v: "dark", t: qsTr("Dark")}, {v: "system", t: qsTr("System")}]
                    delegate: Rectangle {
                        id: tc
                        required property var modelData
                        readonly property bool on: pg.theme_ === modelData.v
                        Layout.fillWidth: true; Layout.preferredHeight: 76; radius: 8
                        color: theme.side; border.width: on ? 2 : 1; border.color: on ? theme.accent : theme.line
                        Behavior on border.color { ColorAnimation { duration: 140 } }
                        Rectangle {   // little preview of the theme
                            x: 12; y: 10; width: 120; height: 56; radius: 6; clip: true; border.width: 1; border.color: theme.line
                            color: tc.modelData.v === "light" ? "#f6f7f2" : "#151817"
                            Rectangle { visible: tc.modelData.v === "system"; x: parent.width / 2; width: parent.width / 2; height: parent.height; color: "#f6f7f2" }
                            Rectangle { x: 0; width: 22; height: parent.height; color: tc.modelData.v === "light" ? "#edf0e8" : "#111411" }
                            Rectangle { x: 32; y: 12; width: 44; height: 6; radius: 3; color: tc.modelData.v === "light" ? "#1d4ed8" : "#85b8ff" }
                            Rectangle { x: 32; y: 26; width: 70; height: 4; radius: 2; color: tc.modelData.v === "light" ? "#dbe0d5" : "#30362f" }
                            Rectangle { x: 32; y: 36; width: 56; height: 4; radius: 2; color: tc.modelData.v === "light" ? "#dbe0d5" : "#30362f" }
                        }
                        Row {
                            x: 146; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Rectangle {
                                width: 14; height: 14; radius: 7; color: "transparent"; border.width: 1.5; border.color: tc.on ? theme.accent : theme.muted; anchors.verticalCenter: parent.verticalCenter
                                Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: theme.accent; visible: tc.on }
                            }
                            Label { text: tc.modelData.t; font.pixelSize: 13; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.s.set("ui/theme", tc.modelData.v) }
                    }
                }
            }
            PrefRow {
                title: qsTr("Album-art colors"); description: qsTr("Use the playing album’s colors with accessible contrast.")
                Toggle { checked: pg.s.flag("ui/artColors"); onToggled: (v) => pg.s.set("ui/artColors", v) }
            }
        }

        PrefCard {
            PrefRow {
                first: true; title: qsTr("Accent color"); description: qsTr("A little color, used with restraint.")
                Row {
                    spacing: 18
                    Repeater {
                        model: [{v: "sage", t: qsTr("Sage"), d: "#c2e99c", l: "#355e24"}, {v: "blue", t: qsTr("Blue"), d: "#85b8ff", l: "#1d4ed8"},
                                {v: "lavender", t: qsTr("Lavender"), d: "#baa1e0", l: "#baa1e0"}, {v: "amber", t: qsTr("Amber"), d: "#ebba66", l: "#ebba66"}]
                        delegate: Column {
                            id: sw
                            required property var modelData
                            readonly property bool on: pg.s.txt("ui/accent") === modelData.v
                            spacing: 5
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter; width: 28; height: 28; radius: 14
                                color: theme.dark ? sw.modelData.d : sw.modelData.l
                                border.width: sw.on ? 2 : 0; border.color: theme.text
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.s.set("ui/accent", sw.modelData.v) }
                            }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: sw.modelData.t; font.pixelSize: 11; color: sw.on ? theme.accent : theme.muted }
                        }
                    }
                }
            }
        }

        PrefCard {
            PrefRow {
                first: true; title: qsTr("Layout density"); description: qsTr("Balance more music with more breathing room.")
                SelectBox {
                    model: [{v: "comfortable", t: qsTr("Comfortable")}, {v: "compact", t: qsTr("Compact")}]; value: pg.s.txt("ui/density")
                    hint: qsTr("More music in less space."); onPicked: (v) => pg.s.set("ui/density", v)
                }
            }
        }
    }
}
