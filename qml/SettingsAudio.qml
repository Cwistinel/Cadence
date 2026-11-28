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
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Audio"); subtitle: qsTr("Choose where sound goes and how loud it can get.") }
        PrefCard {
            heading: qsTr("Output")
            PrefRow {
                first: true; title: qsTr("Audio output"); description: qsTr("Devices available on this computer. If one disconnects, Cadence falls back to the system default.")
                SelectBox {
                    implicitWidth: 260
                    model: [{v: "", t: qsTr("System default")}].concat(pc.devices.map(function (d) { return {v: d, t: d} }))
                    value: pg.s.txt("audio/device"); onPicked: (v) => pg.s.set("audio/device", v)
                }
            }
            PrefRow {
                title: qsTr("Buffer size"); description: qsTr("A larger buffer is steadier; a smaller one reacts faster. Applies from the next track.")
                SelectBox { model: [{v: 100, t: "100 ms"}, {v: 200, t: "200 ms"}, {v: 400, t: "400 ms"}, {v: 800, t: "800 ms"}]; value: pg.s.num("audio/bufferMs"); onPicked: (v) => pg.s.set("audio/bufferMs", v) }
            }
            PrefRow {
                title: qsTr("Exclusive output"); description: qsTr("Managed by your desktop’s sound server.")
                SelectBox { enabled: false; model: [{v: "off", t: qsTr("Unavailable")}]; value: "off" }
            }
        }
        PrefCard {
            heading: qsTr("Volume")
            PrefRow {
                first: true; title: qsTr("Remember volume"); description: qsTr("Start at the volume you last used.")
                Toggle { checked: pg.s.flag("audio/rememberVolume"); onToggled: (v) => pg.s.set("audio/rememberVolume", v) }
            }
            PrefRow {
                title: qsTr("Maximum volume"); description: qsTr("A ceiling for the volume slider and shortcuts.")
                PrefSlider { from: 0.3; to: 1; stepSize: 0.05; value: pg.s.num("audio/maxVolume"); label: Math.round(pg.s.num("audio/maxVolume") * 100) + "%"; onMoved: (v) => pg.s.set("audio/maxVolume", Math.round(v * 100) / 100) }
            }
            PrefRow {
                title: qsTr("Volume normalization"); description: qsTr("Uses the ReplayGain preference in Playback.")
                ActionButton { implicitHeight: 36; text: qsTr("Playback settings"); onClicked: pg.s.goCategory(2) }
            }
        }
    }
}
