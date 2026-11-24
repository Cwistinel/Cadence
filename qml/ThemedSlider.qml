import QtQuick
import QtQuick.Controls

// `bound` keeps the slider following an external value (MPRIS, shortcuts) except while the user holds it.
Slider {
    id: s
    property real bound: NaN
    implicitHeight: 18
    hoverEnabled: true
    Binding { target: s; property: "value"; value: s.bound; when: !s.pressed && !isNaN(s.bound) }
    background: Rectangle {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - height / 2
        width: s.availableWidth; height: 3; radius: 2
        color: theme.line
        Rectangle { width: s.visualPosition * parent.width; height: parent.height; radius: 2; color: theme.accent }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width); y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 10; height: 10; radius: 5; color: theme.text
        opacity: s.hovered || s.pressed ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
}