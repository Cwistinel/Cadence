import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Flickable {
    id: pg
    property var s
    readonly property bool xfade: s.num("audio/crossfadeMs") > 0
    contentWidth: width; contentHeight: col.height + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    ColumnLayout {
        id: col
        width: pg.width; spacing: 12
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Playback"); subtitle: qsTr("How Cadence moves from one song to the next.") }
        RowLayout {
            Layout.fillWidth: true; spacing: 24
            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 12
                PrefCard {
                    heading: qsTr("Between tracks")
                    PrefRow {
                        first: true; title: qsTr("Gapless playback"); description: qsTr("Continuous albums play without a pause.")
                        Toggle { checked: pg.s.flag("audio/gapless"); onToggled: (v) => { pg.s.set("audio/gapless", v); if (v) pg.s.set("audio/crossfadeMs", 0) } }
                    }
                    PrefRow {
                        title: qsTr("Crossfade"); description: pg.s.flag("audio/gapless") ? qsTr("Unavailable while gapless is on.") : qsTr("Fade between tracks instead of a hard cut.")
                        Toggle { enabled: !pg.s.flag("audio/gapless"); checked: pg.xfade; onToggled: (v) => pg.s.set("audio/crossfadeMs", v ? 4000 : 0) }
                    }
                    PrefRow {
                        title: qsTr("Crossfade duration"); description: qsTr("Equal-power fade, no loudness dip.")
                        PrefSlider {
                            enabled: pg.xfade; from: 1000; to: 12000; stepSize: 500; value: Math.max(1000, pg.s.num("audio/crossfadeMs")); label: (Math.max(1000, pg.s.num("audio/crossfadeMs")) / 1000).toFixed(1) + " s"
                            onMoved: (v) => pg.s.set("audio/crossfadeMs", Math.round(v))
                        }
                    }
                }
                PrefCard {
                    heading: qsTr("Resume and loudness")
                    PrefRow {
                        first: true; title: qsTr("Resume previous position"); description: qsTr("Continue where you left off when Cadence starts.")
                        Toggle { checked: pg.s.flag("playback/resume"); onToggled: (v) => pg.s.set("playback/resume", v) }
                    }
                    PrefRow {
                        title: qsTr("ReplayGain"); description: qsTr("Level volume with embedded tags. Gain is limited by each track's peak, so it never clips.")
                        SelectBox { model: [{v: "off", t: qsTr("Off")}, {v: "track", t: qsTr("Track gain")}, {v: "album", t: qsTr("Album gain")}]; value: pg.s.txt("audio/replayGain"); onPicked: (v) => pg.s.set("audio/replayGain", v) }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 12
                PrefCard {
                    heading: qsTr("Playback behavior")
                    PrefRow {
                        first: true; title: qsTr("Shuffle on start"); description: qsTr("How shuffle begins when Cadence opens.")
                        SelectBox { model: [{v: "last", t: qsTr("Remember last")}, {v: "off", t: qsTr("Off")}, {v: "on", t: qsTr("On")}]; value: pg.s.txt("playback/shuffleStart"); onPicked: (v) => pg.s.set("playback/shuffleStart", v) }
                    }
                    PrefRow {
                        title: qsTr("Repeat on start"); description: qsTr("How repeat begins when Cadence opens.")
                        SelectBox { model: [{v: "last", t: qsTr("Remember last")}, {v: "off", t: qsTr("Off")}, {v: "all", t: qsTr("Repeat all")}, {v: "one", t: qsTr("Repeat one")}]; value: pg.s.txt("playback/repeatStart"); onPicked: (v) => pg.s.set("playback/repeatStart", v) }
                    }
                    PrefRow {
                        title: qsTr("Playback speed"); description: qsTr("Pitch is preserved.")
                        SelectBox {
                            model: [{v: 0.5, t: "0.50×"}, {v: 0.75, t: "0.75×"}, {v: 1, t: "1.00×"}, {v: 1.25, t: "1.25×"}, {v: 1.5, t: "1.50×"}, {v: 2, t: "2.00×"}]
                            value: pg.s.num("audio/speed"); onPicked: (v) => pg.s.set("audio/speed", v)
                        }
                    }
                }
            }
        }
    }
}
