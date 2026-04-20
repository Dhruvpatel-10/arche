import QtQuick
import "../theme"

// Icon — a monospace glyph (Nerd Font) at the default icon size. Callers
// override `size` with a Typography token (e.g. Typography.fontLabel) or
// a Sizing.fpx() value; never a raw literal.
Text {
    property int size: Typography.fontIcon
    font.family: Typography.fontMono
    font.pixelSize: size
    color: Colors.fg
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
