import QtQuick

Rectangle {
    property color tone: theme.surface
    color: tone
    radius: 0
    Behavior on color { ColorAnimation { duration: 500 } }
}