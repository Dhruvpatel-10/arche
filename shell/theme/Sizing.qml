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
}
