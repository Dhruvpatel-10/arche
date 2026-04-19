pragma Singleton
import QtQuick

// Colors — warm amber (Ember) on deep charcoal. Every color used anywhere
// in the shell picks from a semantic token here; raw hex in a component
// is tech debt.
//
// (Named Colors, not Palette, because QtQuick Controls already provides a
// `Palette` type that wins the name resolution.)
//
// Surface ladder (deeper → lighter on the dark theme):
//
//   bgAlt < bg < card < bgSurface == pillBg < tileBg < tileBgActive
//
// Reach for the role, not the shade:
//
//   bg            the window/panel background; rarely used as a fill
//   bgAlt         deeper than bg. Text on accent, icon inside active tile
//   card          floating card / drawer surface
//   bgSurface     raised plane under a row group or list
//   pillBg        status pill at rest (in a bar or card)
//   tileBg        toggle tile at rest
//   tileBgActive  toggle tile on hover / active
QtObject {
    // ─── Surface ────────────────────────────────────────────────────────
    readonly property color bg:           "#13151c"
    readonly property color bgAlt:        "#0e1016"
    readonly property color bgSurface:    "#1d2029"
    readonly property color card:         "#181b23"

    readonly property color pillBg:       "#1d2029"
    readonly property color tileBg:       "#22252f"
    readonly property color tileBgActive: "#2f3340"

    // ─── Foreground ─────────────────────────────────────────────────────
    readonly property color fg:      "#cdc8bc"
    readonly property color fgMuted: "#817c72"
    readonly property color fgDim:   "#5a564e"

    // ─── Accent + state ─────────────────────────────────────────────────
    readonly property color accent:    "#c9943e"
    readonly property color accentAlt: "#6a9fb5"
    readonly property color success:   "#7ab87f"
    readonly property color warn:      "#d4a843"
    readonly property color critical:  "#c45c5c"
    readonly property color border:    "#282c38"
}
