import QtQuick

Item {
    id: ic
    property string name: "play"
    property color color: theme.muted
    implicitWidth: 20; implicitHeight: 20
    readonly property string file: name === "speaker" || name === "muted" ? "volume" : name
    function h2(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }
    Image {
        anchors.fill: parent
        visible: ic.file !== "" && ic.name !== "play"
        source: ic.file === "" || ic.name === "play" ? "" : "image://icons/" + ic.file + "?c=" + ic.h2(ic.color.r) + ic.h2(ic.color.g) + ic.h2(ic.color.b)
        sourceSize.width: Math.max(16, ic.width * 2); sourceSize.height: Math.max(16, ic.height * 2)
        fillMode: Image.PreserveAspectFit
        opacity: ic.color.a * (ic.name === "muted" ? 0.55 : 1)
    }
    Canvas {
        id: cv
        anchors.fill: parent
        visible: ic.name === "play"
        onPaint: {
            var g = getContext("2d"); g.reset(); g.fillStyle = ic.color
            g.beginPath(); g.moveTo(width * 0.30, height * 0.16); g.lineTo(width * 0.84, height * 0.5); g.lineTo(width * 0.30, height * 0.84); g.closePath(); g.fill()
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: ic; function onColorChanged() { cv.requestPaint() } }
    }
    Rectangle {
        visible: ic.name === "muted"
        anchors.centerIn: parent; width: parent.width * 1.05; height: Math.max(1.5, parent.height / 12); rotation: 45; radius: height / 2; color: ic.color
    }
}