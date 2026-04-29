import QtQuick
import QtQuick.Layouts
import "../../theme"

// DialogSection — labeled content block for dialog / popover interiors.
//
// Usage:
//   DialogSection {
//       label: "Output"
//       SliderRow { Layout.fillWidth: true; ... }
//   }
//
// Renders a small uppercase-feel section label (muted) above the content,
// matching the rhythm used across AudioMixerPopover / NetworkPopover /
// BatteryPopover. When `label` is empty the section is an unlabeled
// group — useful when you just want a consistent gap contract around
// a row.
ColumnLayout {
    id: root

    // Human-readable label. Empty = unlabeled block (no label Text).
    property string label: ""

    // Default children go into the content column.
    default property alias content: body.data

    Layout.fillWidth: true
    spacing: Spacing.xs

    Text {
        Layout.fillWidth: true
        visible: root.label.length > 0
        text: root.label
        color: Colors.fgMuted
        font.family: Typography.fontSans
        font.pixelSize: Typography.fontMicro
        font.weight: Typography.weightMedium
        elide: Text.ElideRight
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Spacing.xs
    }
}
