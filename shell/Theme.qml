pragma Singleton
import QtQuick
import "theme"

// Facade over the modular theme/* singletons. New code should import
// "theme" and use Colors / Typography / Spacing / Shape / Effects /
// Motion / Sizing directly. This singleton forwards every token so
// existing components keep working while migration proceeds.
//
// DEPRECATION: do not add new tokens here. Every role defined in a
// theme/* module should be reachable through the facade, but net-new
// design tokens live in their modular home. If you need a new role,
// add it to theme/Colors.qml (etc.), then forward it here — never
// invent a Theme-only token. See docs/theming.md.
//
// Legacy aliases (fontSize, fontSizeSmall, gap, pad, padLg, …) stay
// for back-compat but are the first candidates to remove.
QtObject {
    // ─── Palette — surfaces ────────────────────────────────────────────
    readonly property color bg:                 Colors.bg
    readonly property color bgAlt:              Colors.bgAlt
    readonly property color bgSurface:          Colors.bgSurface
    readonly property color card:               Colors.card
    readonly property color pillBg:             Colors.pillBg
    readonly property color pillBgHover:        Colors.pillBgHover
    readonly property color tileBg:             Colors.tileBg
    readonly property color tileBgActive:       Colors.tileBgActive
    readonly property color islandInk:          Colors.islandInk
    readonly property color islandInkHover:     Colors.islandInkHover
    readonly property color surfaceOpaque:      Colors.surfaceOpaque
    readonly property color surfaceTranslucent: Colors.surfaceTranslucent
    readonly property color crust:              Colors.crust

    // ─── Palette — foreground ─────────────────────────────────────────
    readonly property color fg:         Colors.fg
    readonly property color fgMuted:    Colors.fgMuted
    readonly property color fgDim:      Colors.fgDim
    readonly property color fgOnActive: Colors.fgOnActive

    // ─── Palette — accent + state ─────────────────────────────────────
    readonly property color accent:            Colors.accent
    readonly property color accentAlt:         Colors.accentAlt
    readonly property color success:           Colors.success
    readonly property color warn:              Colors.warn
    readonly property color critical:          Colors.critical
    readonly property color border:            Colors.border
    readonly property color separator:         Colors.separator
    readonly property color workspaceOccupied: Colors.workspaceOccupied

    // ─── Palette — dialog + danger ────────────────────────────────────
    readonly property color dialogScrim:   Colors.dialogScrim
    readonly property color dialogSurface: Colors.dialogSurface
    readonly property color dialogBorder:  Colors.dialogBorder
    readonly property color dangerBg:      Colors.dangerBg
    readonly property color dangerBorder:  Colors.dangerBorder

    // ─── Typography ────────────────────────────────────────────────────
    readonly property string fontSans: Typography.fontSans
    readonly property string fontMono: Typography.fontMono

    readonly property int fontMicro:   Typography.fontMicro
    readonly property int fontCaption: Typography.fontCaption
    readonly property int fontBody:    Typography.fontBody
    readonly property int fontLabel:   Typography.fontLabel
    readonly property int fontTitle:   Typography.fontTitle
    readonly property int fontIcon:    Typography.fontIcon
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

    // ─── Effects ───────────────────────────────────────────────────────
    readonly property real opacitySubtle: Effects.opacitySubtle
    readonly property real opacityMuted:  Effects.opacityMuted
    readonly property real opacityActive: Effects.opacityActive

    readonly property int  shadowBlur:    Effects.shadowBlur
    readonly property int  shadowYOffset: Effects.shadowYOffset
    readonly property real shadowOpacity: Effects.shadowOpacity

    readonly property real surfaceAlpha:            Effects.surfaceAlpha
    readonly property real surfaceAlphaOpaque:      Effects.surfaceAlphaOpaque
    readonly property real surfaceAlphaTranslucent: Effects.surfaceAlphaTranslucent

    readonly property int  shadowBarBlur:    Effects.shadowBarBlur
    readonly property int  shadowBarY:       Effects.shadowBarY
    readonly property real shadowBarOpacity: Effects.shadowBarOpacity

    readonly property int  shadowDialogBlur:    Effects.shadowDialogBlur
    readonly property int  shadowDialogYOffset: Effects.shadowDialogYOffset
    readonly property real shadowDialogOpacity: Effects.shadowDialogOpacity

    // ─── Component dimensions (forwarded from Sizing) ─────────────────
    // Component-level presets that scale with layoutScale so a 4K display
    // gets a proportionally taller bar and wider drawer. Definitions live
    // in theme/Sizing.qml; this block is facade-only.
    readonly property int barHeight:          Sizing.barHeight
    readonly property int controlCenterWidth: Sizing.controlCenterWidth

    // ─── Scale passthrough ─────────────────────────────────────────────
    readonly property real fontScale:   Sizing.fontScale
    readonly property real layoutScale: Sizing.layoutScale
}
