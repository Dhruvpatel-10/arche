import QtQuick
import "../theme"

// StateLayer — Material 3 hover/press overlay. Drop inside any rect that
// wants the standard tint-on-hover / brighten-on-press feedback. Reads
// state from a MouseArea passed in as `source`; when no source is given,
// the layer is just a static transparent tint.
//
// Opacity ladder:
//    rest     0.00
//    hover    0.08
//    pressed  0.10
//
// Usage:
//   Rectangle {
//       color: Theme.pillBg
//       radius: Theme.radiusPill
//       MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }
//       StateLayer { anchors.fill: parent; source: mouse; tint: Theme.fg }
//   }
//
// Pattern from /tmp/shell components/StateLayer.qml, simplified: no
// ripple, just the tint overlay. Ripples are 170 lines of Shape +
// RadialGradient and we decided opacity overlays are enough polish.
Rectangle {
    id: root
    property var source: null       // MouseArea-like: .containsMouse, .pressed
    property color tint: "#ffffff"  // overlay color (hover/press tint)
    property real radius: 0         // match parent.radius for matched corners

    color: tint
    opacity: {
        if (!source) return 0
        if (source.pressed) return 0.10
        if (source.containsMouse) return 0.08
        return 0
    }

    Behavior on opacity {
        Anim { type: "fast" }
    }
}
