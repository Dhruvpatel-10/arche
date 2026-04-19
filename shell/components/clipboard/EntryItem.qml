import QtQuick
import QtQuick.Layouts
import "../.."

// Single row in the entry list. Images show a type glyph + "Image" label +
// dimension/size badge; text rows show the preview line truncated.
Rectangle {
    id: root

    required property var  entry
    required property bool selected

    signal activated()
    signal removed()

    implicitHeight: 48
    radius: 8
    color: selected
        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.11)
        : "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (m) => m.button === Qt.RightButton
            ? root.removed()
            : root.activated()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin:  14
            rightMargin: 14
        }
        spacing: 12

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.entry.isImage ? "\uf03e" : "\uf15c"
            color: root.selected ? Theme.accent : Theme.fgMuted
            font { family: Theme.fontMono; pixelSize: Theme.fontLabel }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
            text: root.entry.isImage ? "Image" : root.entry.preview
            color: Theme.fg
            font { family: Theme.fontSans; pixelSize: Theme.fontBody }
        }

        Text {
            visible: root.entry.isImage
            Layout.alignment: Qt.AlignVCenter
            text: root.entry.width + "×" + root.entry.height + "  ·  " + root.entry.sizeText
            color: Theme.fgDim
            font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
        }
    }
}
