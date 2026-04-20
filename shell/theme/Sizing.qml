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
    function px(base: real): int  { return Math.round(base * layoutScale) }

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
        return Math.round(base * layoutScaleFor(screenName))
    }
    function fpxFor(base: real, screenName: string): int {
        return Math.round(base * fontScaleFor(screenName))
    }

    // ─── Component-level chrome dimensions ────────────────────────────
    // Role-named wrappers over px(N) so the Theme facade and consumers
    // can refer to `Sizing.barHeight` instead of an unlabelled literal.
    // Only add entries here that every shell deployment shares.
    readonly property int barHeight:          px(38)
    readonly property int controlCenterWidth: px(420)
}
