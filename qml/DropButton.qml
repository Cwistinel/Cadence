import QtQuick
import QtQuick.Controls

// An outlined action button that opens a menu of {v, t} options.
ActionButton {
    id: d
    property var options: []
    signal aboutToOpen()
    signal picked(var value)
    onClicked: { aboutToOpen(); m.popup(0, height + 4) }
    StyledMenu {
        id: m
        Instantiator {
            model: d.options
            delegate: StyledMenuItem { required property var modelData; text: modelData.t; onTriggered: d.picked(modelData.v) }
            onObjectAdded: (i, o) => m.insertItem(i, o)
            onObjectRemoved: (i, o) => m.removeItem(o)
        }
    }
}