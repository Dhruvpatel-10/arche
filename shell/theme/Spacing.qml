pragma Singleton
import QtQuick
import "."

// Spacing — 4px base grid, six steps. Reach by role; don't invent.
//
//   xs    4  between icon and label inside a pill (tight, inline)
//   sm    6  between related inline items (pill row, tag row)
//   smMd  8  between tiles in a toggle grid, stat cards, toast list rows
//   md   10  pill / row inner padding
//   lg   16  card / drawer inner padding
//   xl   24  between card sections; between a drawer and its tiles
//
// If you catch yourself writing `Spacing.md * 2` more than once in the
// same file, promote it to a new step rather than multiplying.
QtObject {
    readonly property int xs:   Sizing.px(4)
    readonly property int sm:   Sizing.px(6)
    readonly property int smMd: Sizing.px(8)
    readonly property int md:   Sizing.px(10)
    readonly property int lg:   Sizing.px(16)
    readonly property int xl:   Sizing.px(24)

    // ─── Named semantic aliases (StyledDialog) ─────────────────────────
    // dialogPad         card inner padding
    // dialogContentGap  gap between title / body / action rows
    // dialogInset       margin from card to screen edge (scrim margin)
    readonly property int dialogPad:        lg
    readonly property int dialogContentGap: md
    readonly property int dialogInset:      xl
}
