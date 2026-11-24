import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Cadence 1.0

// Scrolling track table: optional header content, the "# / TITLE / ALBUM / TIME" columns, optional day sections.
ListView {
    id: list
    readonly property var app: Window.window
    property var lib                               // a songs-mode LibraryModel
    property bool showColumns: true
    property bool sections: false
    property bool useTrackNo: false
    property string emptyText: ""
    property Component headerContent: null
    property var sectionText: function (s) { return s }
    property var sel: ({})
    readonly property bool compact: (settings.revision, settings.text("ui/density", "comfortable") === "compact")
    readonly property string firstSection: (count, sections && lib ? lib.sectionAt(0) : "")

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }
    function select(id, m) {
        var s = (m.modifiers & Qt.ControlModifier) ? Object.assign({}, sel) : ({})
        if (s[id] && (m.modifiers & Qt.ControlModifier)) delete s[id]; else s[id] = true
        sel = s
    }
    function openMenu(id, fav) {
        var multi = sel[id] && Object.keys(sel).length > 1
        ctx.ids = multi ? Object.keys(sel).map(Number) : [id]
        ctx.single = multi ? 0 : id
        ctx.fav = fav
        ctx.popup()
    }

    clip: true; model: lib; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    onContentYChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()
    onCountChanged: if (lib && contentHeight - contentY - height < 800) lib.loadMore()

    TrackMenu { id: ctx; app: list.app }
    Shortcut { sequence: "Ctrl+A"; enabled: list.visible; onActivated: { var s = ({}); list.lib.allIds().forEach(function (i) { s[i] = true }); list.sel = s } }

    Component {
        id: colsComp
        Item {
            width: list.width; height: 29
            RowLayout {
                x: 12; width: parent.width - 28; height: 28; spacing: 12
                Label { Layout.preferredWidth: 22; text: "#"; font.pixelSize: 11; color: theme.muted }
                Item { visible: !list.compact; Layout.preferredWidth: 36 }
                Label { Layout.fillWidth: true; Layout.preferredWidth: 300; text: qsTr("TITLE / ARTIST"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
                Label { Layout.fillWidth: true; Layout.preferredWidth: 521; text: qsTr("ALBUM"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
                Label { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: qsTr("TIME"); font.pixelSize: 10; font.letterSpacing: 0.6; color: theme.muted }
                Item { Layout.preferredWidth: 77 }
            }
            Rectangle { y: 28; width: parent.width; height: 1; color: theme.line }
        }
    }

    header: Column {
        width: list.width
        Loader { width: parent.width; sourceComponent: list.headerContent }
        Loader { width: parent.width; active: list.showColumns && !list.sections; visible: active; sourceComponent: colsComp }
    }
    footer: Item {
        width: list.width; height: list.count === 0 && list.emptyText !== "" ? 140 : 0
        Label { anchors.centerIn: parent; visible: parent.height > 0; horizontalAlignment: Text.AlignHCenter; color: theme.muted; text: list.emptyText }
    }

    section.property: sections ? "section" : ""
    section.criteria: ViewSection.FullString
    section.delegate: Column {
        required property string section
        width: list.width; topPadding: section === list.firstSection ? 0 : 20; spacing: 12
        Label { text: list.sectionText(parent.section); font.pixelSize: 17; font.weight: Font.DemiBold }
        Loader { width: parent.width; active: list.showColumns && parent.section === list.firstSection; visible: active; sourceComponent: colsComp }
    }

    delegate: TrackRow {
        width: ListView.view ? ListView.view.width : 0
        compact: list.compact
        playing: pc.track.id === trackId
        selected: !!list.sel[trackId]
        number: list.useTrackNo ? extra : index + 1
        dragIds: list.sel[trackId] ? Object.keys(list.sel).map(Number) : [trackId]
        onRowClicked: (m) => list.select(trackId, m)
        onPlayRequested: pc.playTracks(list.lib.allIds(), index)
        onMenuRequested: list.openMenu(trackId, favorite)
        onFavoriteToggled: pc.setFavorite(trackId, !favorite)
    }
}