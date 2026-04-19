pragma Singleton
import QtQuick
import "."

// Effects — opacity, shadow, surface-alpha tokens.
//
// Philosophy: backdrop blur is OFF for all Quickshell surfaces at the
// compositor level (see stow/hypr/.config/hypr/looknfeel.conf). Cards use
// fully-opaque hex colors; depth comes from shadow + surface contrast,
// not blur. This keeps edges crisp and eliminates the halo around toasts
// and rounded card corners that appears on dark backgrounds when
// blur-through is on.
//
// If you think you want blur, you almost certainly want either:
//   1. a shadow under the surface above, or
//   2. a surface step up (card → bgSurface → tileBg).
QtObject {
    // ─── Opacity ───────────────────────────────────────────────────────
    // Three steps only. Don't invent intermediate values — it looks like
    // a bug when five different dividers each have a unique alpha.
    readonly property real opacitySubtle: 0.5   // inner dividers, hairlines
    readonly property real opacityMuted:  0.7   // secondary meta over bg
    readonly property real opacityActive: 1.0

    // ─── Shadow ────────────────────────────────────────────────────────
    // Consumed by MultiEffect (Qt Quick 6.5+) or DropShadow on cards
    // and popups. All three scale with layout so shadows stay
    // proportional on dense displays.
    readonly property int  shadowBlur:    Sizing.px(20)
    readonly property int  shadowYOffset: Sizing.px(4)
    readonly property real shadowOpacity: 0.33

    // ─── Surface alpha ─────────────────────────────────────────────────
    // All Quickshell cards are fully opaque. Kept as a token so hyprlock
    // and future semi-transparent overlays share one source of truth.
    readonly property real surfaceAlpha: 1.0
}
