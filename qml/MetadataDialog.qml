import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: d
    property int trackId: 0
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    width: 440
    title: qsTr("Edit metadata")
    standardButtons: Dialog.Save | Dialog.Reset | Dialog.Cancel
    function edit(id) {
        trackId = id
        var c = meta.get(id).current
        fTitle.text = c.title; fArtist.text = c.artist; fAlbum.text = c.album; fAA.text = c.albumArtist; fGenre.text = c.genre
        fNo.text = c.trackNo > 0 ? c.trackNo : ""
        open()
    }
    onAccepted: meta.save(trackId, {title: fTitle.text, artist: fArtist.text, album: fAlbum.text, albumArtist: fAA.text, genre: fGenre.text, trackNo: parseInt(fNo.text) || 0})
    onReset: { meta.reset(trackId); edit(trackId) }
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        Label { Layout.fillWidth: true; wrapMode: Text.Wrap; color: theme.subtext; font.pixelSize: 12; text: qsTr("Edits are stored in Cadence only. Your audio files are never modified. Reset restores the file's own tags.") }
        GridLayout {
            columns: 2; columnSpacing: 10; rowSpacing: 6; Layout.fillWidth: true
            Label { text: qsTr("Title") } TextField { id: fTitle; Layout.fillWidth: true }
            Label { text: qsTr("Artist") } TextField { id: fArtist; Layout.fillWidth: true }
            Label { text: qsTr("Album") } TextField { id: fAlbum; Layout.fillWidth: true }
            Label { text: qsTr("Album artist") } TextField { id: fAA; Layout.fillWidth: true }
            Label { text: qsTr("Genre") } TextField { id: fGenre; Layout.fillWidth: true }
            Label { text: qsTr("Track no.") } TextField { id: fNo; Layout.fillWidth: true; inputMethodHints: Qt.ImhDigitsOnly }
        }
    }
}