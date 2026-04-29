pragma Singleton
import QtQuick
import Quickshell

// Sizing — two independent scale axes so typography and chrome move on
// their own.
//
//   ARCHE_SHELL_FONT_SCALE    — typography (accessibility knob)
//   ARCHE_SHELL_LAYOUT_SCALE  — chrome: pad, gap, radii, panel widths
//
// Both default to 1.0 and clamp to [0.75, 2.0]. A stray 0.1 in someone's
// shell rc must not brick the shell. Components never read environment
// variables directly — call Sizing.px / Sizing.fpx.
//
// (Named Sizing, not Scale, because QtQuick already has a `Scale`
// transform type that wins the name resolution.)
QtObject {
    readonly property real fontScale: {
        const raw = parseFloat(Quickshell.env("ARCHE_SHELL_FONT_SCALE") || "")
        if (isNaN(raw) || raw <= 0) return 1.0
        return Math.max(0.75, Math.min(2.0, raw))
    }

    readonly property real layoutScale: {
        const raw = parseFloat(Quickshell.env("ARCHE_SHELL_LAYOUT_SCALE") || "")
        if (isNaN(raw) || raw <= 0) return 1.0
        return Math.max(0.75, Math.min(2.0, raw))
    }

    // Scale a logical pixel value by layoutScale and round to an integer.
    // Use for padding, radii, panel widths, icon boxes — anything chrome.
    //
    // Guard: hairline 1-logical-px borders survive low scales. Without the
    // `base >= 1 ? Math.max(1, ...)` clamp, `px(1)` at layoutScale 0.75
    // would round to 1 (fine) but a future 0.6 clamp leak would round to 0
    // and the border vanishes. Zero-base (e.g. `px(0.5)`) is preserved as-is
    // so sub-pixel spacers still collapse.
    function px(base: real): int {
        const raw = base * layoutScale
        if (base > 0 && raw < 1) return 1
        return Math.round(raw)
    }

    // Scale a logical pixel value by fontScale. Use for font pixelSize.
    function fpx(base: real): int { return Math.round(base * fontScale) }

    // ─── Per-screen scale overrides ───────────────────────────────────
    // Contract: set ARCHE_SHELL_LAYOUT_SCALE_<screenname> or
    // ARCHE_SHELL_FONT_SCALE_<screenname> (dashes in the Hyprland monitor
    // name become underscores: HDMI-A-1 → HDMI_A_1). Absent or invalid
    // values fall back to the global layoutScale / fontScale.
    //
    // Use pxFor / fpxFor in per-screen surfaces (bar wings, OSDs spawned
    // via Variants { model: Quickshell.screens }). Drawers that show on
    // the focused monitor only keep using px / fpx.
    function _envScale(varName: string): real {
        const raw = parseFloat(Quickshell.env(varName) || "")
        if (isNaN(raw) || raw <= 0) return NaN
        return Math.max(0.75, Math.min(2.0, raw))
    }
    function layoutScaleFor(screenName: string): real {
        if (!screenName) return layoutScale
        const v = _envScale("ARCHE_SHELL_LAYOUT_SCALE_" + screenName.replace(/-/g, "_"))
        return isNaN(v) ? layoutScale : v
    }
    function fontScaleFor(screenName: string): real {
        if (!screenName) return fontScale
        const v = _envScale("ARCHE_SHELL_FONT_SCALE_" + screenName.replace(/-/g, "_"))
        return isNaN(v) ? fontScale : v
    }
    function pxFor(base: real, screenName: string): int {
        const raw = base * layoutScaleFor(screenName)
        if (base > 0 && raw < 1) return 1
        return Math.round(raw)
    }
    function fpxFor(base: real, screenName: string): int {
        return Math.round(base * fontScaleFor(screenName))
    }

    // ─── Component-level chrome dimensions ────────────────────────────
    // Role-named wrappers over px(N) so the Theme facade and consumers
    // can refer to `Sizing.barHeight` instead of an unlabelled literal.
    // Only add entries here that every shell deployment shares.
    //
    // Bar: the wings + center clock all agree on a single logical height.
    // barHeightLogical is the pre-scale base — wings call
    // Sizing.pxFor(Sizing.barHeightLogical, screenName) so a per-screen
    // scale env var can bump the bar (and all its contents) on a physically
    // larger monitor without touching callers.
    readonly property int barHeightLogical:   30
    readonly property int barHeight:          px(barHeightLogical)
    function barHeightFor(screenName: string): int {
        return pxFor(barHeightLogical, screenName)
    }
    readonly property int controlCenterWidth: px(420)
}
