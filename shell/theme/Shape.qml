pragma Singleton
import QtQuick
import "."

// Shape — corner radii and border widths. All radii scale with layout so
// a pill stays pill-shaped on 4K and a tile doesn't get visibly sharper
// on a higher-density display.
//
// Ladder borrowed from Material 3 / Caelestia:
//
//   radiusXs      4    inline chips, dots, tiny hit targets
//   radiusSm     12    grouped row backgrounds, inline cards
//   radiusNormal 17    toggle tiles, notification bubbles, drawer cards —
//                       17 (not 16) is the deliberate M3 friendlier curve
//   radiusLarge  25    larger floating surfaces, lift-off cards
//   radiusFull 1000    pills, circles, "as round as the shape allows"
//
// Legacy aliases (radius, radiusTile, radiusPill, radiusLg) stay for
// back-compat; new code reaches for the M3 names above.
QtObject {
    // ─── M3 ladder ─────────────────────────────────────────────────────
    readonly property int radiusXs:     Sizing.px(4)
    readonly property int radiusSm:     Sizing.px(12)
    readonly property int radiusNormal: Sizing.px(17)
    readonly property int radiusLarge:  Sizing.px(25)
    readonly property int radiusFull:   1000

    // ─── Legacy aliases ────────────────────────────────────────────────
    // Old token names resolve into the M3 ladder. Prefer the ladder.
    readonly property int radius:     radiusNormal
    readonly property int radiusTile: radiusNormal
    readonly property int radiusPill: radiusFull
    readonly property int radiusLg:   radiusLarge

    // ─── Border widths ─────────────────────────────────────────────────
    // Hairlines stay 1px — scaling them rounds to 2 on >=1.5x and reads
    // as a fat outline. borderMd scales for explicit emphasis.
    readonly property int borderThin: 1
    readonly property int borderMd:   Math.max(1, Math.round(Sizing.layoutScale))
}
