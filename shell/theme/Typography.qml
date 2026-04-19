pragma Singleton
import QtQuick
import "."

// Typography — one ladder, two families. Never put a raw pixelSize in a
// component; pick a role token. If nothing fits, the design is probably
// off before a new size is.
//
// Pick by role, not by number:
//
//   fontMicro    10  meta that must recede (minutes-ago, dense subtitles)
//   fontCaption  12  badges, subtitles, key hints, dim meta
//   fontBody     14  default body copy, list row titles
//   fontLabel    15  emphasized row title, small-icon glyphs
//   fontTitle    17  modal search input, card section title
//   fontDisplay  30  hero numerics only (clock, one big % in a card)
QtObject {
    // ─── Families ──────────────────────────────────────────────────────
    readonly property string fontSans: "IBM Plex Sans"
    readonly property string fontMono: "MesloLGS Nerd Font Mono"

    // ─── Size ladder ───────────────────────────────────────────────────
    // Logical pixels pre-scale; Sizing.fpx rounds after applying fontScale.
    readonly property int fontMicro:   Sizing.fpx(10)
    readonly property int fontCaption: Sizing.fpx(12)
    readonly property int fontBody:    Sizing.fpx(14)
    readonly property int fontLabel:   Sizing.fpx(15)
    readonly property int fontTitle:   Sizing.fpx(17)
    readonly property int fontDisplay: Sizing.fpx(30)

    // ─── Weight presets ────────────────────────────────────────────────
    // We use three in practice. Skip Bold / Black — too heavy for the
    // dark palette, they smudge at small sizes.
    readonly property int weightNormal:   Font.Normal
    readonly property int weightMedium:   Font.Medium
    readonly property int weightDemiBold: Font.DemiBold
}
