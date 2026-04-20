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

    // islandInk — the living notch's fill. A hair below bgAlt so the
    // island reads as a void taken *out* of the screen rather than a card
    // floating on top. See docs/island-design.md principle 2.
    readonly property color islandInk:    "#0d0e12"
    readonly property color islandInkHover: "#14161d"

    // ─── Foreground ─────────────────────────────────────────────────────
    readonly property color fg:      "#cdc8bc"
    readonly property color fgMuted: "#817c72"
    readonly property color fgDim:   "#5a564e"

    // fgOnActive — the punctuation fill for an "active" affordance (icon
    // disc on an active ToggleTile, etc.). Pure white intentionally, not
    // `fg`: the extra chroma contrast against tileBgActive signals state
    // faster than the warm off-white text color does.
    readonly property color fgOnActive: "#ffffff"

    // ─── Accent + state ─────────────────────────────────────────────────
    readonly property color accent:    "#c9943e"
    readonly property color accentAlt: "#6a9fb5"
    readonly property color success:   "#7ab87f"
    readonly property color warn:      "#d4a843"
    readonly property color critical:  "#c45c5c"
    readonly property color border:    "#282c38"

    // ─── Adaptive bar surface ───────────────────────────────────────────
    // Driven by the bar's per-screen `opacityScale` (0 → translucent, 1 →
    // opaque). Translucent = bgSurface at 78% alpha so the wallpaper reads
    // through subtly. Opaque = a half-step brighter than bgSurface so the
    // bar has its own ground when a fullscreen window takes over the
    // workspace under it.
    readonly property color surfaceOpaque:      "#20232c"
    readonly property color surfaceTranslucent: Qt.rgba(0x1d/255.0, 0x20/255.0, 0x29/255.0, 0.78)

    // ─── Bar pill hover (distinct from drawer tileBgActive) ─────────────
    // Bar pills get their own hover role so drawer polish can shift
    // tileBgActive without dragging the bar's hover along. pillBg
    // (at rest) already exists above.
    readonly property color pillBgHover:  "#262a35"

    // ─── Workspace + separator chrome ───────────────────────────────────
    // Occupied-but-inactive tile border and pill-group vertical rule
    // share a hex today (half-step between border and tileBg, slightly
    // warmer). Two named roles so future divergence is a one-file edit.
    readonly property color workspaceOccupied: "#3a3e4c"
    readonly property color separator:         "#3a3e4c"

    // ─── Shadow tint ────────────────────────────────────────────────────
    // Warm-black for drop shadows under bar and dialog surfaces. Reads
    // neutral against the charcoal palette rather than the cool pure
    // black a naked DropShadow would default to.
    readonly property color crust: "#0a0b10"

    // ─── Dialog (StyledDialog consumers) ────────────────────────────────
    // Decoupled from surfaceOpaque/Translucent intentionally: dialogs are
    // always fully opaque regardless of what the bar is doing. Aliases for
    // now — the name is the contract; divergence is a one-file change.
    readonly property color dialogScrim:   Qt.rgba(0, 0, 0, 0.45)
    readonly property color dialogSurface: card
    readonly property color dialogBorder:  border

    // Danger action styling (Confirm dialog destructive button).
    // Outlined, not filled — a filled red rectangle next to a charcoal
    // card reads as an alert banner; this is a confirmation.
    readonly property color dangerBg:     Qt.rgba(critical.r, critical.g, critical.b, 0.11)
    readonly property color dangerBorder: critical
}
