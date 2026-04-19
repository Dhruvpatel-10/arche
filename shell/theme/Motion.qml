pragma Singleton
import QtQuick

// Motion — animation durations + easings. Two-tier system borrowed from
// Material 3 (via Caelestia /tmp/shell tokens.hpp):
//
//   Standard / Emphasized  — UI state transitions (hover, fade, reveal).
//                            Smooth, cubic, no overshoot.
//   Expressive Spatial     — physical movement (drawer slide, list items
//                            landing, toggle snapping into place). Easing
//                            overshoots slightly so motion feels "alive"
//                            without spending on a spring engine.
//
// Pick duration by intent:
//
//   durationFast    tooltips, state flash, hover highlight     (~120 ms)
//   durationStd     standard UI transition (fade, recolor)     (~200 ms)
//   durationMed     content swap, section change, pane cross   (~350 ms)
//   durationLarge   drawer open/close, full-layer transitions  (~500 ms)
//   durationXL      staged enters, intro animations            (~650 ms)
//
// Legacy aliases (durationInstant, durationSlow, easeOut, easeSpring, …)
// stay for back-compat; new code picks from the named set above.
QtObject {
    // ─── Duration tokens (ms) ──────────────────────────────────────────
    readonly property int durationFast:    120
    readonly property int durationStd:     200
    readonly property int durationMed:     350
    readonly property int durationLarge:   500
    readonly property int durationXL:      650

    // Legacy aliases — do not use in new code.
    readonly property int durationInstant: 80
    readonly property int durationSlow:    320

    // ─── Easing curves (cubic bezier control points) ───────────────────
    // QML exposes BezierSpline easings as an array of control points
    // [x1,y1, x2,y2, endx, endy]. The last pair MUST be (1,1); we repeat
    // it so consumers can splice these into Easing.bezierCurve: […].

    // Standard — Material 3 standard curve. Cubic with gentle accel in,
    // soft decel out. Default for state transitions that start and end
    // at rest (hover, color fade, opacity reveal).
    readonly property var standard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    // Emphasized — slight acceleration hold in the middle for larger
    // layout changes (sheet resize, content shift). More "premium" feel.
    readonly property var emphasized: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]

    // Standard Accelerate — content leaving the screen. Use for fade-OUT
    // halves of paired swaps.
    readonly property var standardAccel: [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]

    // Standard Decelerate — content entering. Use for fade-IN halves.
    readonly property var standardDecel: [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]

    // Expressive Default Spatial — overshoots y=1.21 then settles. This
    // is the single biggest "feels alive" win in a QML shell: use for
    // drawer offsetScale, list items settling into place, tile snap on
    // active. Don't use for opacity or color — only spatial properties.
    readonly property var expressiveSpatial: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]

    // Expressive Fast Spatial — same overshoot, tighter profile. For
    // lighter movements like a button press-release.
    readonly property var expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1.0, 1.0]

    // ─── Legacy named easings (enum form) ──────────────────────────────
    // New code: use the bezier-spline arrays above via
    //   easing { type: Easing.BezierSpline; bezierCurve: Motion.standard }
    // These stay so existing `easing.type: Motion.easeOut` keeps working.
    readonly property int easeOut:    Easing.OutCubic
    readonly property int easeInOut:  Easing.InOutCubic
    readonly property int easeSpring: Easing.OutBack

    // OutBack overshoot — keep small; matches hypr apple_pop's 1.275.
    readonly property real springOvershoot: 1.2
}
