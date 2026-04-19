import QtQuick
import "../theme"

// Anim — NumberAnimation preset selector. Picks a consistent
// (duration, easing) pair via a single `type` string so components
// don't need to spell out both.
//
//   "fast"        120 ms / standard      — hover, quick state flashes
//   "standard"    200 ms / standard      — default fade, recolor (DEFAULT)
//   "emphasized"  200 ms / emphasized    — premium-feel state change
//   "med"         350 ms / standard      — content swap
//   "accel"       200 ms / standardAccel — paired-swap leaving half
//   "decel"       200 ms / standardDecel — paired-swap arriving half
//   "spatial"     500 ms / expressiveSpatial     — drawers, lands
//   "fastSpatial" 350 ms / expressiveFastSpatial — toggle snaps
//
// Usage:
//   Behavior on offsetScale { Anim { type: "spatial" } }
//   NumberAnimation-like otherwise — so still works as a step inside
//   a SequentialAnimation / ParallelAnimation.
NumberAnimation {
    id: root
    property string type: "standard"

    duration: {
        switch (root.type) {
            case "fast":        return Motion.durationFast
            case "standard":    return Motion.durationStd
            case "emphasized":  return Motion.durationStd
            case "med":         return Motion.durationMed
            case "accel":       return Motion.durationStd
            case "decel":       return Motion.durationStd
            case "spatial":     return Motion.durationLarge
            case "fastSpatial": return Motion.durationMed
            default:            return Motion.durationStd
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (root.type) {
            case "emphasized":  return Motion.emphasized
            case "accel":       return Motion.standardAccel
            case "decel":       return Motion.standardDecel
            case "spatial":     return Motion.expressiveSpatial
            case "fastSpatial": return Motion.expressiveFastSpatial
            default:            return Motion.standard
        }
    }
}
