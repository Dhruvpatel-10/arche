import QtQuick
import QtQuick.Layouts
import "../.."
import "../picker"

// Single row in the entry list. Images show a type glyph + "Image"
// label + dimension/size badge; text rows show the preview line
// truncated. Right-click removes (PickerItemBase handles the button
// wiring via `rightClickRemoves`).
PickerItemBase {
    id: root

    required property var entry

    rightClickRemoves: true

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
            elide: LayoutMirroring.enabled ? Text.ElideLeft : Text.ElideRight
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
