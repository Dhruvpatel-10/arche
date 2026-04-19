pragma Singleton
import QtQuick
import "theme"

// Facade over the modular theme/* singletons. New code should import
// "theme" and use Colors / Typography / Spacing / Shape / Effects /
// Motion / Sizing directly. This singleton forwards every token so
// existing components keep working while migration proceeds.
//
// Legacy aliases (fontSize, fontSizeSmall, gap, pad, padLg, …) live
// here — don't add new ones. If you need a new token, add it to the
// appropriate source module instead. See docs/theming.md.
QtObject {
    // ─── Palette ───────────────────────────────────────────────────────
    readonly property color bg:           Colors.bg
    readonly property color bgAlt:        Colors.bgAlt
    readonly property color bgSurface:    Colors.bgSurface
    readonly property color card:         Colors.card
    readonly property color pillBg:       Colors.pillBg
    readonly property color tileBg:       Colors.tileBg
    readonly property color tileBgActive: Colors.tileBgActive

    readonly property color fg:      Colors.fg
    readonly property color fgMuted: Colors.fgMuted
    readonly property color fgDim:   Colors.fgDim

    readonly property color accent:    Colors.accent
    readonly property color accentAlt: Colors.accentAlt
    readonly property color success:   Colors.success
    readonly property color warn:      Colors.warn
    readonly property color critical:  Colors.critical
    readonly property color border:    Colors.border

    // ─── Typography ────────────────────────────────────────────────────
    readonly property string fontSans: Typography.fontSans
    readonly property string fontMono: Typography.fontMono

    readonly property int fontMicro:   Typography.fontMicro
    readonly property int fontCaption: Typography.fontCaption
    readonly property int fontBody:    Typography.fontBody
    readonly property int fontLabel:   Typography.fontLabel
    readonly property int fontTitle:   Typography.fontTitle
    readonly property int fontDisplay: Typography.fontDisplay

    // Legacy font aliases — used by existing components.
    readonly property int fontSize:      Typography.fontBody
    readonly property int fontSizeSmall: Typography.fontCaption
    readonly property int fontSizeLarge: Typography.fontLabel
    readonly property int fontSizeXL:    Typography.fontDisplay

    // ─── Spacing (legacy names) ────────────────────────────────────────
    // New code: prefer Spacing.xs / sm / md / lg / xl.
    readonly property int gap:   Spacing.sm
    readonly property int pad:   Spacing.md
    readonly property int padLg: Spacing.lg

    // ─── Shape ─────────────────────────────────────────────────────────
    readonly property int radius:     Shape.radius
    readonly property int radiusPill: Shape.radiusPill
    readonly property int radiusTile: Shape.radiusTile
    readonly property int radiusLg:   Shape.radiusLg
    readonly property int radiusSm:   Shape.radiusSm
    readonly property int radiusXs:   Shape.radiusXs

    // ─── Component dimensions ──────────────────────────────────────────
    // These are component-level presets, not primitives. They scale with
    // layoutScale so a 4K display gets a proportionally taller bar and
    // wider drawer without any per-component override.
    readonly property int barHeight:          Sizing.px(38)
    readonly property int controlCenterWidth: Sizing.px(420)

    // ─── Scale passthrough ─────────────────────────────────────────────
    readonly property real fontScale:   Sizing.fontScale
    readonly property real layoutScale: Sizing.layoutScale
}
