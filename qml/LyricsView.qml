import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: lv
    readonly property var app: Window.window
    readonly property string fam: (settings.revision, settings.text("lyrics/fontFamily", ""))
    readonly property int fsz: (settings.revision, settings.number("lyrics/fontSize", 26))
    readonly property int wgt: (settings.revision, settings.number("lyrics/fontWeight", 500))
    readonly property string align: (settings.revision, settings.text("lyrics/align", "center"))
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        RowLayout {
            Label { Layout.fillWidth: true; elide: Text.ElideRight; color: theme.subtext
                text: (pc.hasTrack ? pc.track.title : "") + (lyrics.hasLyrics ? "  ·  " + (lyrics.source === "edited" ? qsTr("your edited copy") : lyrics.source === "file" ? qsTr("from .lrc file") : qsTr("embedded in file")) : "") }
            Button { text: qsTr("Style"); onClicked: style.open() }
            Button { text: qsTr("Edit"); enabled: pc.hasTrack; onClicked: lv.app.editLyrics() }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: lyrics.lines
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: Math.max(0, lyrics.currentLine)
            highlightRangeMode: lyrics.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            preferredHighlightBegin: height / 2 - 30; preferredHighlightEnd: height / 2 + 30
            highlightMoveDuration: 350
            highlight: Item {}
            ScrollBar.vertical: ScrollBar {}
            delegate: Label {
                required property int index
                required property var modelData
                readonly property bool active: lyrics.synced && index === lyrics.currentLine
                width: ListView.view.width
                wrapMode: Text.Wrap
                text: modelData.text === "" ? " " : modelData.text
                horizontalAlignment: lv.align === "left" ? Text.AlignLeft : lv.align === "right" ? Text.AlignRight : Text.AlignHCenter
                font.family: lv.fam || Qt.application.font.family
                font.pixelSize: lv.fsz; font.weight: lv.wgt
                color: active ? theme.accent : theme.text
                Behavior on color { ColorAnimation { duration: 250 } }
                scale: active ? 1.05 : 1
                transformOrigin: lv.align === "left" ? Item.Left : lv.align === "right" ? Item.Right : Item.Center
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                opacity: lyrics.synced && !active ? 0.45 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
                topPadding: 6; bottomPadding: 6
                MouseArea { anchors.fill: parent; enabled: lyrics.synced; onClicked: pc.seek(modelData.ms) }
            }
        }
        Label {
            visible: !lyrics.hasLyrics; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: theme.subtext
            text: qsTr("No lyrics found next to the file or inside it.\nPress Edit to paste, import an .lrc file, or write them.")
        }
    }
    Popup {
        id: style
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true; padding: 16
        contentItem: ColumnLayout {
            spacing: 8
            Label { text: qsTr("Lyrics style"); font.bold: true }
            ComboBox {
                Layout.fillWidth: true; model: [qsTr("Default font")].concat(Qt.fontFamilies())
                currentIndex: Math.max(0, Qt.fontFamilies().indexOf(lv.fam) + 1)
                onActivated: settings.setValue("lyrics/fontFamily", currentIndex ? currentText : "")
            }
            RowLayout { Label { text: qsTr("Size"); Layout.fillWidth: true } SpinBox { from: 12; to: 72; value: lv.fsz; onValueModified: settings.setValue("lyrics/fontSize", value) } }
            RowLayout {
                Label { text: qsTr("Weight"); Layout.fillWidth: true }
                ComboBox { textRole: "t"; valueRole: "v"; model: [{v: 400, t: qsTr("Normal")}, {v: 500, t: qsTr("Medium")}, {v: 700, t: qsTr("Bold")}]; currentIndex: Math.max(0, indexOfValue(lv.wgt)); onActivated: settings.setValue("lyrics/fontWeight", currentValue) }
            }
            RowLayout {
                Label { text: qsTr("Alignment"); Layout.fillWidth: true }
                ComboBox { textRole: "t"; valueRole: "v"; model: [{v: "left", t: qsTr("Left")}, {v: "center", t: qsTr("Center")}, {v: "right", t: qsTr("Right")}]; currentIndex: Math.max(0, indexOfValue(lv.align)); onActivated: settings.setValue("lyrics/align", currentValue) }
            }
            Button { Layout.alignment: Qt.AlignRight; text: qsTr("Close"); onClicked: style.close() }
        }
    }
}