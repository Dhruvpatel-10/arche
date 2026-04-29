import QtQuick
import QtQuick.Layouts
import "../../theme"

// DialogDivider — thin horizontal rule for separating header / sections /
// footer inside an ArcheDialog. One opacity, one color, one height — so
// every rule in every popover sits at the same visual weight.
//
// Use inside a ColumnLayout (dialog content area). `Layout.fillWidth` is
// set so the rule spans the card's inner content width.
Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Colors.separator
    opacity: Effects.opacitySubtle
}
