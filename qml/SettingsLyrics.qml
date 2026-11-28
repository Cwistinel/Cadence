import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Lyrics"); subtitle: qsTr("Shape how lyrics look and behave.") }
        PrefCard {
            heading: qsTr("Typography")
            PrefRow {
                first: true; title: qsTr("Font"); description: qsTr("Used for lyric lines.")
                SelectBox {
                    implicitWidth: 240
                    model: [{v: "", t: qsTr("System default")}].concat(Qt.fontFamilies().map(function (f) { return {v: f, t: f} }))
                    value: pg.s.txt("lyrics/fontFamily"); onPicked: (v) => pg.s.set("lyrics/fontFamily", v)
                }
            }
            PrefRow {
                title: qsTr("Font size"); description: qsTr("The current line is shown a third larger.")
                SelectBox { model: [{v: 18, t: "18 px"}, {v: 20, t: "20 px"}, {v: 22, t: "22 px"}, {v: 24, t: "24 px"}, {v: 28, t: "28 px"}, {v: 32, t: "32 px"}]; value: pg.s.num("lyrics/fontSize"); onPicked: (v) => pg.s.set("lyrics/fontSize", v) }
            }
            PrefRow {
                title: qsTr("Alignment"); description: qsTr("Where lyric lines sit in the view.")
                SelectBox { model: [{v: "left", t: qsTr("Left")}, {v: "center", t: qsTr("Center")}, {v: "right", t: qsTr("Right")}]; value: pg.s.txt("lyrics/align"); onPicked: (v) => pg.s.set("lyrics/align", v) }
            }
            Rectangle {   // preview
                Layout.fillWidth: true; Layout.topMargin: 6; Layout.bottomMargin: 8; Layout.preferredHeight: 92; radius: 8; color: theme.side
                Label { x: 14; y: 10; text: qsTr("LYRICS PREVIEW"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.muted }
                Label {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14; y: 36
                    horizontalAlignment: pg.s.txt("lyrics/align") === "left" ? Text.AlignLeft : pg.s.txt("lyrics/align") === "right" ? Text.AlignRight : Text.AlignHCenter
                    elide: Text.ElideRight; text: qsTr("Leave the weight of yesterday")
                    font.family: pg.s.txt("lyrics/fontFamily") || Qt.application.font.family; font.pixelSize: pg.s.num("lyrics/fontSize")
                }
            }
        }
        PrefCard {
            heading: qsTr("Timing and display")
            PrefRow {
                first: true; title: qsTr("Synchronized scrolling"); description: qsTr("Keep the current line centered as the song plays.")
                Toggle { checked: pg.s.flag("lyrics/follow"); onToggled: (v) => pg.s.set("lyrics/follow", v) }
            }
            PrefRow {
                title: qsTr("Default display mode"); description: qsTr("What you see when a song has synchronized lyrics.")
                SelectBox { model: [{v: "synced", t: qsTr("Synchronized")}, {v: "plain", t: qsTr("Plain")}]; value: pg.s.txt("lyrics/defaultMode"); onPicked: (v) => pg.s.set("lyrics/defaultMode", v) }
            }
            PrefRow {
                title: qsTr("Show untimed lyrics"); description: qsTr("Show plain text lyrics when no synchronized file is available.")
                Toggle { checked: pg.s.flag("lyrics/plainFallback"); onToggled: (v) => pg.s.set("lyrics/plainFallback", v) }
            }
            PrefRow {
                title: qsTr("Timestamp adjustment"); description: qsTr("For the playing song, applied right away. Negative values show lyrics earlier.")
                ActionButton { implicitHeight: 36; text: "−100 ms"; enabled: pc.hasTrack; onClicked: lyrics.adjustOffset(-100) }
                SelectBox {
                    implicitWidth: 110; enabled: pc.hasTrack
                    model: [-500, -300, -100, 0, 100, 300, 500].map(function (v) { return {v: v, t: (v > 0 ? "+" : "") + v + " ms"} }).concat(
                           [-500, -300, -100, 0, 100, 300, 500].indexOf(lyrics.offsetMs) < 0 ? [{v: lyrics.offsetMs, t: (lyrics.offsetMs > 0 ? "+" : "") + lyrics.offsetMs + " ms"}] : [])
                    value: lyrics.offsetMs; onPicked: (v) => lyrics.adjustOffset(v - lyrics.offsetMs)
                }
                ActionButton { implicitHeight: 36; text: "+100 ms"; enabled: pc.hasTrack; onClicked: lyrics.adjustOffset(100) }
            }
        }
    }
}
