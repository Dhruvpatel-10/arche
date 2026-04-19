import QtQuick
import "../theme"

// StyledRect — Rectangle with two things every surface wants:
//
//   1. Default `color: "transparent"` so forgotten fills don't flash
//      the old Qt6 default white on first paint.
//   2. `Behavior on color` wired to the Motion.standard curve so theme
//      switches and state color changes animate for free. No need to
//      repeat ColorAnimation boilerplate at every callsite.
//
// Use this instead of bare `Rectangle` for any surface that might
// change color (hover, active, theme swap). Raw Rectangle stays fine
// for purely decorative static shapes.
//
// Philosophy borrowed from Caelestia /tmp/shell components/StyledRect.qml.
Rectangle {
    color: "transparent"
    Behavior on color {
        ColorAnimation {
            duration: Motion.durationFast
            easing.type: Motion.easeOut
        }
    }
}
