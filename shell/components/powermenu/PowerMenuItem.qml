import QtQuick
import QtQuick.Layouts
import "../.."
import "../picker"

// PowerMenuItem — single row in the power menu list: glyph + label.
// Row chrome (selection tint, hover, click) comes from PickerItemBase;
// this file supplies only the two columns of content.
PickerItemBase {
    id: root

    required property var action

    RowLayout {
        anchors {
            fill: parent
            leftMargin:  14
            rightMargin: 14
        }
        spacing: 14

        Text {
            Layout.alignment: Qt.AlignVCenter
            text:  root.action.icon
            color: root.selected ? Theme.accent : Theme.fgMuted
            font {
                family:    Theme.fontMono
                pixelSize: Theme.fontLabel
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: LayoutMirroring.enabled ? Text.ElideLeft : Text.ElideRight
            text:  root.action.label
            color: Theme.fg
            font {
                family:    Theme.fontSans
                pixelSize: Theme.fontBody
            }
        }
    }
}
