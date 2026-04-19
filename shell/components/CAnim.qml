import QtQuick
import "../theme"

// CAnim — ColorAnimation sibling of Anim. Same `type` tokens, but a
// reduced set — color transitions only use the non-spatial curves.
// (Color channels have no physical meaning, so overshoot easings are
// nonsense on them.)
//
//   "fast"       120 ms / standard     — hover tint swaps
//   "standard"   200 ms / standard     — default recolor (DEFAULT)
//   "emphasized" 200 ms / emphasized
//   "accel"      200 ms / standardAccel
//   "decel"      200 ms / standardDecel
ColorAnimation {
    id: root
    property string type: "standard"

    duration: {
        switch (root.type) {
            case "fast":       return Motion.durationFast
            case "emphasized": return Motion.durationStd
            case "accel":      return Motion.durationStd
            case "decel":      return Motion.durationStd
            default:           return Motion.durationStd
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (root.type) {
            case "emphasized": return Motion.emphasized
            case "accel":      return Motion.standardAccel
            case "decel":      return Motion.standardDecel
            default:           return Motion.standard
        }
    }
}
