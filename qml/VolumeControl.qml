import QtQuick
import QtQuick.Layouts

RowLayout {
    property int sliderWidth: 97
    spacing: 10
    Layout.fillWidth: false
    IconButton { size: 28; iconSize: 20; icon: pc.muted || pc.volume === 0 ? "muted" : "volume"; color: theme.muted; tip: qsTr("Mute"); onClicked: pc.muted = !pc.muted }
    ThemedSlider { Layout.preferredWidth: sliderWidth; from: 0; to: 1; bound: pc.volume; onMoved: { pc.muted = false; pc.volume = value } }
}