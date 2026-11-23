import QtQuick
import QtQuick.Controls

// `bound` keeps the slider following an external value (MPRIS, shortcuts) except while the user holds it.
Slider {
    id: s
    property real bound: NaN
    implicitHeight: 24
    Binding { target: s; property: "value"; value: s.bound; when: !s.pressed && !isNaN(s.bound) }
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth; height: 4; radius: 2
        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.2)
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: theme.accent }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width); y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.pressed ? 18 : 14; height: width; radius: width / 2; color: theme.accent
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
}