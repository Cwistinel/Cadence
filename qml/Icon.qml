import QtQuick

Canvas {
    id: c
    property string name: "play"
    property color color: "white"
    implicitWidth: 24; implicitHeight: 24
    onColorChanged: requestPaint()
    onNameChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var g = getContext("2d"), w = width, h = height
        g.reset()
        g.fillStyle = c.color; g.strokeStyle = c.color; g.lineWidth = Math.max(1, w / 12)
        function poly(p) { g.beginPath(); g.moveTo(p[0] * w, p[1] * h); for (var i = 2; i < p.length; i += 2) g.lineTo(p[i] * w, p[i + 1] * h); g.closePath(); g.fill() }
        function bar(x0, x1) { g.fillRect(x0 * w, 0.18 * h, (x1 - x0) * w, 0.64 * h) }
        switch (c.name) {
        case "play": poly([0.28, 0.15, 0.86, 0.5, 0.28, 0.85]); break
        case "pause": bar(0.22, 0.42); bar(0.58, 0.78); break
        case "next": poly([0.15, 0.2, 0.7, 0.5, 0.15, 0.8]); bar(0.74, 0.86); break
        case "prev": poly([0.85, 0.2, 0.3, 0.5, 0.85, 0.8]); bar(0.14, 0.26); break
        case "speaker":
        case "muted":
            poly([0.1, 0.38, 0.3, 0.38, 0.52, 0.18, 0.52, 0.82, 0.3, 0.62, 0.1, 0.62])
            g.beginPath()
            if (c.name === "speaker") {
                g.arc(0.52 * w, 0.5 * h, 0.2 * w, -0.9, 0.9); g.stroke()
                g.beginPath(); g.arc(0.52 * w, 0.5 * h, 0.34 * w, -0.9, 0.9); g.stroke()
            } else {
                g.moveTo(0.64 * w, 0.38 * h); g.lineTo(0.9 * w, 0.62 * h); g.moveTo(0.9 * w, 0.38 * h); g.lineTo(0.64 * w, 0.62 * h); g.stroke()
            }
            break
        }
    }
}