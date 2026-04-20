import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../theme"

// StyledDialog — unified centered modal primitive.
//
// Extends StyledWindow with a role enum (Picker | Confirm), a scrim,
// a card, one `offsetScale` numeric driver (trap #9: one driver, derived
// bindings), and a single `dismissed(reason)` signal covering every exit
// path so consumers grep one handler instead of three signals.
//
// Usage:
//   StyledDialog {
//       name: "powermenu-confirm"   // → "arche-powermenu-confirm" namespace
//       role: 1                     // 0 = Picker, 1 = Confirm
//       open: PowerMenu.confirmOpen
//       maxWidth:  Sizing.px(380)
//       maxHeight: Sizing.px(220)
//       // content goes here as default children
//   }
//
// Roles:
//   0 (Picker)  — keyboard Exclusive, 480×560, content = search input
//   1 (Confirm) — keyboard Exclusive, caller-supplied max dims, content = title/body/buttons
//
// Dismissal reasons emitted via dismissed(reason: string):
//   "outside"      scrim click
//   "esc"          Escape key
//   "commit"       Enter on Picker (consumer accepts selected item)
//   "cancel"       Cancel button on Confirm
//   "action"       Danger button on Confirm
//   "monitor-left" focused monitor changed away
StyledWindow {
    id: root

    // ─── Role constants ────────────────────────────────────────────────
    // why: QML enum syntax is valid but accessing it from sub-types
    // requires the qualified name (StyledDialog.Role.Picker) which only
    // resolves after the type is registered. Integer constants are
    // simpler and more portable across QML engine versions.
    readonly property int rolePicker:  0
    readonly property int roleConfirm: 1

    // ─── Public API ────────────────────────────────────────────────────
    property int  role:      0  // 0 = Picker, 1 = Confirm
    property bool open:      false
    // Default card dims. Callers override maxWidth/maxHeight as needed.
    property int  maxWidth:  Sizing.px(480)
    property int  maxHeight: Sizing.px(560)
    // Confirm: when true, focus starts on the danger button instead of Cancel.
    // Default false — Cancel must be the safe default (user's explicit Tab
    // is required to reach the destructive action).
    property bool dangerDefault: false

    // Default content slot — children appear inside the card body.
    default property alias content: contentItem.data

    signal dismissed(string reason)

    // ─── Geometry ──────────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ─── Animation driver ─────────────────────────────────────────────
    // One numeric driver: 0 = fully open, 1 = fully closed.
    // Scrim opacity + card opacity + card y-translate all derive from it.
    // No racing Behaviors (trap #9).
    property real offsetScale: open ? 0 : 1
    visible: open || offsetScale < 1
    Behavior on offsetScale { Anim { type: "dialog" } }

    // ─── Multi-monitor dismiss ─────────────────────────────────────────
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!root.open) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                root.dismissed("monitor-left")
        }
    }

    // ─── Scrim ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.dialogScrim
        opacity: 1 - root.offsetScale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed("outside")
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  Math.min(root.maxWidth,  parent.width  - Spacing.dialogInset * 2)
        height: Math.min(root.maxHeight, parent.height - Spacing.dialogInset * 2)
        color:  Colors.dialogSurface
        radius: Shape.radiusDialog
        border.color: Colors.dialogBorder
        border.width: Shape.borderThin

        opacity: 1 - root.offsetScale
        transform: Translate { y: root.offsetScale * Sizing.px(8) }

        // Swallow clicks so the scrim dismissal doesn't fire for
        // interactions inside the card.
        MouseArea { anchors.fill: parent }

        // Inner padding container where consumer content lives.
        Item {
            id: contentItem
            anchors {
                fill: parent
                margins: Spacing.dialogPad
            }
        }
    }
}
