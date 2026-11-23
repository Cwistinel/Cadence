import QtQuick
import QtQuick.Controls

Menu {
    id: m
    property var app
    property var ids: []
    property int single: 0
    property bool fav: false
    MenuItem { text: qsTr("Play"); onTriggered: pc.playTracks(m.ids) }
    MenuItem { text: qsTr("Play next"); onTriggered: pc.enqueue(m.ids, true) }
    MenuItem { text: qsTr("Add to queue"); onTriggered: pc.enqueue(m.ids) }
    Menu {
        id: pls
        title: qsTr("Add to playlist")
        Instantiator {
            model: playlists.playlists
            delegate: MenuItem { required property var modelData; text: modelData.name; onTriggered: playlists.addTracks(modelData.id, m.ids) }
            onObjectAdded: (i, o) => pls.insertItem(i, o)
            onObjectRemoved: (i, o) => pls.removeItem(o)
        }
    }
    MenuItem { text: qsTr("Add to new playlist…"); onTriggered: m.app.askName(qsTr("New playlist"), "", function (n) { playlists.addTracks(playlists.create(n), m.ids) }) }
    MenuItem { visible: m.single > 0; height: visible ? implicitHeight : 0; text: m.fav ? qsTr("Remove favorite") : qsTr("Add favorite"); onTriggered: pc.setFavorite(m.single, !m.fav) }
    MenuItem { visible: m.single > 0; height: visible ? implicitHeight : 0; text: qsTr("Edit metadata…"); onTriggered: m.app.openMeta(m.single) }
}