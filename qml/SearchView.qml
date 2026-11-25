import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

Item {
    id: v
    readonly property var app: Window.window
    property string query: ""
    readonly property string q: query.trim()
    readonly property var matchAll: ({text: "\u0001"})              // matches nothing: keeps the models empty until something is typed
    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function fmt(ms) { var t = Math.floor(ms / 1000); return Math.floor(t / 60) + ":" + ("0" + t % 60).slice(-2) }

    LibraryModel { id: songs; mode: "songs"; sort: "title"; filters: v.q ? ({text: v.q}) : v.matchAll; limit: 5 }
    LibraryModel { id: albums; mode: "albums"; sort: "title"; filters: v.q ? ({text: v.q}) : v.matchAll; limit: 3 }
    LibraryModel { id: artists; mode: "artists"; sort: "title"; filters: v.q ? ({text: v.q}) : v.matchAll; limit: 8 }
    readonly property int artistIdx: {
        var ql = q.toLowerCase()
        for (var i = 0; i < artists.total; ++i) if (artists.get(i).artist.toLowerCase().indexOf(ql) >= 0) return i
        return -1
    }
    readonly property string topKind: artistIdx >= 0 ? "artist" : albums.total > 0 ? "album" : songs.total > 0 ? "song" : ""
    readonly property var topResult: topKind === "artist" ? artists.get(artistIdx) : topKind === "album" ? albums.get(0) : topKind === "song" ? songs.get(0) : ({})
    readonly property var plMatches: playlists.playlists.filter(function (p) { return q !== "" && p.name.toLowerCase().indexOf(q.toLowerCase()) >= 0 })
    readonly property bool hasResults: topKind !== "" || plMatches.length > 0

    function takePending() { if (app.pendingQuery !== "") { field.text = app.pendingQuery; app.pendingQuery = "" } }
    Component.onCompleted: { takePending(); field.forceActiveFocus() }
    Connections { target: v.app; function onPendingQueryChanged() { v.takePending() } }
    Timer { id: deb; interval: 150; onTriggered: v.query = field.text }
    Shortcut { sequence: "Ctrl+K"; enabled: v.visible; onActivated: { field.forceActiveFocus(); field.selectAll() } }

    ColumnLayout {
        anchors.fill: parent; anchors.leftMargin: 32; anchors.rightMargin: 32; anchors.topMargin: 21; spacing: 20
        PageHeading { Layout.fillWidth: true; searchable: false; title: qsTr("Search"); subtitle: qsTr("Results from your music folders only") }

        Rectangle {   // the large search field
            Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 8; color: theme.panel
            border.width: 1; border.color: field.activeFocus ? theme.accent : theme.line
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                Label { text: "⌕"; font.pixelSize: 24; color: theme.accent }
                TextField {
                    id: field
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search songs, albums, artists and playlists"); placeholderTextColor: theme.muted
                    font.pixelSize: 18; color: theme.text; selectByMouse: true
                    background: null; leftPadding: 0; rightPadding: 0
                    onTextChanged: deb.restart()
                }
                Label { visible: field.text !== ""; text: "×"; font.pixelSize: 22; color: theme.muted
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { field.text = ""; field.forceActiveFocus() } } }
            }
        }

        Label {
            visible: v.q === "" || !v.hasResults
            Layout.fillWidth: true; Layout.topMargin: 40; horizontalAlignment: Text.AlignHCenter; color: theme.muted
            text: v.q === "" ? qsTr("Type to search your songs, albums, artists and playlists.") : qsTr("Nothing matches “%1”.").arg(v.q)
        }

        RowLayout {
            visible: v.q !== "" && v.hasResults
            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 32

            Rectangle {   // top result
                visible: v.topKind !== ""
                Layout.preferredWidth: 260; Layout.preferredHeight: 332; Layout.alignment: Qt.AlignTop
                radius: 10; color: theme.panel
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 10
                    Label { text: qsTr("TOP RESULT"); font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: theme.muted }
                    Cover { Layout.preferredWidth: 150; Layout.preferredHeight: 150; rpx: 9; trackId: v.topResult.trackId || 0; px: 300 }
                    Label { Layout.fillWidth: true; Layout.topMargin: 2; elide: Text.ElideRight; font.pixelSize: 22; font.weight: Font.DemiBold; text: v.topResult.title || "" }
                    Label {
                        Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: theme.muted
                        text: v.topKind === "artist" ? qsTr("Artist · %1 songs").arg(v.topResult.count || 0)
                            : v.topKind === "album" ? qsTr("Album · %1").arg(v.topResult.artist || "") : qsTr("Song · %1").arg(v.topResult.artist || "")
                    }
                    Item { Layout.fillHeight: true }
                    ActionButton {
                        primary: true
                        text: v.topKind === "artist" ? qsTr("Play artist") : v.topKind === "album" ? qsTr("Play album") : qsTr("Play")
                        onClicked: {
                            if (v.topKind === "artist") pc.playTracks(artists.idsFor(v.artistIdx))
                            else if (v.topKind === "album") pc.playTracks(albums.idsFor(0))
                            else pc.playTracks([v.topResult.trackId])
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; anchors.bottomMargin: 70; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (v.topKind === "artist") v.app.openArtist(v.topResult.artist); else if (v.topKind === "album") v.app.openAlbum(v.topResult.album, v.topResult.albumArtist) }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; spacing: 15

                Label { visible: songs.total > 0; text: qsTr("Songs"); font.pixelSize: 18; font.weight: Font.DemiBold }
                Repeater {
                    model: songs
                    delegate: Rectangle {
                        id: sr
                        required property int index
                        required property var trackId
                        required property string title
                        required property string artist
                        required property string album
                        required property var durationMs
                        Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 7
                        color: sma.containsMouse ? v.a(theme.text, 0.05) : "transparent"
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pc.playTracks(songs.allIds(), sr.index) }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 12; spacing: 12
                            Cover { Layout.preferredWidth: 38; Layout.preferredHeight: 38; rpx: 9; trackId: sr.trackId; px: 96 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; text: sr.title }
                                Label { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 11; color: theme.muted; text: sr.artist + (sr.album ? " · " + sr.album : "") }
                            }
                            Label { font.pixelSize: 12; color: theme.muted; text: v.fmt(sr.durationMs) }
                        }
                    }
                }

                Label { visible: albums.total > 0; Layout.topMargin: 6; text: qsTr("Albums"); font.pixelSize: 18; font.weight: Font.DemiBold }
                Repeater {
                    model: albums
                    delegate: Item {
                        id: ar
                        required property int index
                        required property var trackId
                        required property string title
                        required property string artist
                        required property string album
                        required property string albumArtist
                        required property int year
                        Layout.fillWidth: true; Layout.preferredHeight: 72
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: v.app.openAlbum(ar.album, ar.albumArtist) }
                        RowLayout {
                            anchors.fill: parent; spacing: 12
                            Cover { Layout.preferredWidth: 72; Layout.preferredHeight: 72; rpx: 9; trackId: ar.trackId; px: 160 }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter; spacing: 6
                                Label { font.pixelSize: 16; font.weight: Font.Medium; text: ar.title }
                                Label { font.pixelSize: 12; color: theme.muted; text: ar.artist + (ar.year > 0 ? " · " + ar.year : "") }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }

                Label {
                    visible: v.plMatches.length > 0; Layout.topMargin: 6; font.pixelSize: 13; color: theme.muted
                    text: qsTr("Playlists · %1 match: %2").arg(v.plMatches.length).arg(v.plMatches.map(function (p) { return p.name }).join(", "))
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { v.app.plId = v.plMatches[0].id; v.app.showPage("playlist") } }
                }
                Item { Layout.fillHeight: true }
            }
        }
        Item { Layout.fillHeight: true; visible: v.q === "" || !v.hasResults }
    }
}