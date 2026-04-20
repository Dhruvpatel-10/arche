import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../theme"

// WingPopover — reusable shell for the right-wing's focused popovers
// (Notifications, Audio, Network, Bluetooth, Battery). Each instance is
// a per-screen layer surface that drops from under the right wing,
// scrims the monitor for outside-click dismissal, and renders a caller-
// supplied `contentComponent` inside the card.
//
// Why Component-via-Loader and not a default property alias:
//   A `default property alias X: child.data` on a QML type routes ALL
//   children declared INSIDE that type's body — including our internal
//   scrim MouseArea and card Rectangle — into `child.data`, breaking
//   the nesting. A `Component`-based slot keeps the internal surface
//   intact and gives the caller a clean one-liner.
//
// Usage (from a Variants { model: Quickshell.screens } block):
//
//   WingPopover {
//       popoverId: "notifs"
//       name:      "popover-notifs"
//       cardWidth: Sizing.px(380)
//       anchorRightMargin: Sizing.px(12)
//       property var modelData; screen: modelData
//
//       contentComponent: Component {
//           Column {
//               width: parent.width
//               spacing: Spacing.md
//               NotificationsList { width: parent.width }
//           }
//       }
//   }
StyledWindow {
    id: root

    // The Ui.rightPopover value that opens this popover. Required.
    property string popoverId: ""

    // Card size + anchor (tuned per-popover).
    property int   cardWidth:         Sizing.px(360)
    property int   anchorRightMargin: Sizing.px(10)
    property int   anchorTopMargin:   Sizing.px(4)

    // Content slot — caller supplies a Component. The Loader instantiates
    // it inside the card and takes its implicitHeight for card sizing.
    property Component contentComponent: null

    // Show iff the Ui flag matches us. Kept painted through the close
    // animation so the slide isn't truncated when the flag flips off.
    readonly property bool shouldBeActive: Ui.rightPopover === popoverId
    property real offsetScale: shouldBeActive ? 0 : 1
    visible: shouldBeActive || offsetScale < 1

    Behavior on offsetScale { Anim { type: "spatial" } }

    // Full monitor (below the bar) so the scrim MouseArea catches
    // click-outside without swallowing clicks on other monitors.
    // ExclusionMode.Auto shrinks this layer out of the bar's exclusive
    // zone, so parent.top sits just below it.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Dismiss when the cursor moves to another monitor (Hyprland's
    // follow_mouse=1 default tracks cursor → focusedMonitor).
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!root.shouldBeActive) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                Ui.closePopover()
        }
    }

    // Grace-period close: fires when cursor leaves the card and doesn't
    // return within the window. Short enough to feel responsive, long
    // enough to allow reading before acting.
    Timer {
        id: leaveTimer
        interval: 600
        onTriggered: Ui.closePopover()
    }

    // Scrim: outside-click dismissal. Click anywhere outside the card →
    // close immediately. Intentionally does NOT set `hoverEnabled` — we
    // don't want this full-screen MouseArea's enter/leave to arm the
    // grace-period timer. The card's HoverHandler is the sole driver of
    // "cursor left the card → start countdown"; duplicating the signal
    // here used to silently auto-close the popover the instant it opened.
    // Left-button only — right-clicks fall through to whatever's beneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Ui.closePopover()
    }

    // The popover card itself.
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: root.anchorTopMargin
                           + (-card.height - Sizing.px(12)) * root.offsetScale
        anchors.right: parent.right
        anchors.rightMargin: root.anchorRightMargin
        width: root.cardWidth
        height: (contentLoader.item?.implicitHeight ?? 0) + Spacing.lg * 2
        color: Colors.card
        radius: Shape.radiusLg
        border.color: Colors.border
        border.width: Shape.borderThin
        opacity: 1 - root.offsetScale
        clip: true

        // Cancel grace-period close when cursor re-enters the card.
        HoverHandler {
            onHoveredChanged: {
                if (hovered) leaveTimer.stop()
                else         leaveTimer.restart()
            }
        }

        // Swallow clicks on the card so the scrim dismiss handler
        // doesn't fire when interacting inside the popover.
        MouseArea { anchors.fill: parent }

        // Caller's content is instantiated here. Width is fixed to the
        // card's padded width; the content binds `width: parent.width`
        // (== Loader.width) to get the available drawable area, and its
        // implicitHeight feeds the card's height.
        Loader {
            id: contentLoader
            x: Spacing.lg
            y: Spacing.lg
            width: card.width - Spacing.lg * 2
            sourceComponent: root.contentComponent
        }
    }
}
