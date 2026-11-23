import QtQuick
import QtQuick.Layouts

RowLayout {
    property int sliderWidth: 108
    spacing: 4
    Layout.fillWidth: false
    IconButton { size: 32; icon: pc.muted || pc.volume === 0 ? "muted" : "speaker"; color: theme.subtext; tip: qsTr("Mute"); onClicked: pc.muted = !pc.muted }
    ThemedSlider { Layout.preferredWidth: sliderWidth; from: 0; to: 1; bound: pc.volume; onMoved: { pc.muted = false; pc.volume = value } }
}