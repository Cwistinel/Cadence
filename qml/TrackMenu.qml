import QtQuick
import QtQuick.Controls

StyledMenu {
    id: m
    property var app
    property var ids: []
    property int single: 0
    property bool fav: false
    StyledMenuItem { text: "▶  " + qsTr("Play now"); accentText: true; onTriggered: pc.playTracks(m.ids) }
    StyledMenuItem { text: qsTr("Play next"); onTriggered: pc.enqueue(m.ids, true) }
    StyledMenuItem { text: qsTr("Add to queue"); onTriggered: pc.enqueue(m.ids) }
    StyledMenuItem { visible: m.single > 0; height: visible ? implicitHeight : 0; text: m.fav ? "♥  " + qsTr("Remove from favorites") : "♡  " + qsTr("Add to favorites"); onTriggered: pc.setFavorite(m.single, !m.fav) }
    StyledMenu {
        id: pls
        title: qsTr("Add to playlist") + "  ›"
        StyledMenuItem { text: qsTr("New playlist…"); onTriggered: m.app.askName(qsTr("New playlist"), "", function (n) { playlists.addTracks(playlists.create(n), m.ids) }) }
        Instantiator {
            model: playlists.playlists
            delegate: StyledMenuItem { required property var modelData; text: modelData.name; onTriggered: playlists.addTracks(modelData.id, m.ids) }
            onObjectAdded: (i, o) => pls.insertItem(i + 1, o)
            onObjectRemoved: (i, o) => pls.removeItem(o)
        }
    }
    StyledMenuItem { visible: m.single > 0; height: visible ? implicitHeight : 0; text: qsTr("Edit track details"); onTriggered: m.app.openMeta(m.single) }
    StyledMenuItem { visible: m.single > 0; height: visible ? implicitHeight : 0; text: qsTr("Show in folder"); onTriggered: scanner.showInFolder(m.single) }
}