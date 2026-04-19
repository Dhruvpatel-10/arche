pragma Singleton
import QtQuick
import "."

// Spacing — 4px base grid, five steps. Reach by role; don't invent.
//
//   xs  4  between icon and label inside a pill (tight, inline)
//   sm  6  between related inline items (pill row, tag row)
//   md 10  pill / row inner padding
//   lg 16  card / drawer inner padding
//   xl 24  between card sections; between a drawer and its tiles
//
// If you catch yourself writing `Spacing.md * 2` more than once in the
// same file, promote it to a new step rather than multiplying.
QtObject {
    readonly property int xs: Sizing.px(4)
    readonly property int sm: Sizing.px(6)
    readonly property int md: Sizing.px(10)
    readonly property int lg: Sizing.px(16)
    readonly property int xl: Sizing.px(24)
}
