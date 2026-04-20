import QtQuick
import Quickshell
import Quickshell.Wayland

// StyledWindow — PanelWindow wrapper that gives every layer surface a
// unique Hyprland namespace. Hyprland layerrules can then target one
// surface at a time:
//
//   layerrule blur match:namespace arche-clipboard
//   layerrule animation slide match:namespace arche-controlcenter
//
// Pattern from Caelestia /tmp/shell components/containers/StyledWindow.qml.
// Usage:
//
//   StyledWindow {
//       name: "controlcenter"
//       anchors { top: true; bottom: true; left: true; right: true }
//       ...
//   }
//
// Without a `name`, the default "arche-shell" namespace is used — which
// matches every unnamed arche surface, so always set a name.
//
// Pitfall #6: the Wayland namespace is *construction-only*. The attached
// property binding below is evaluated before the surface commits, so the
// ternary is effectively a compile-time expression — callers that set
// `name` as a string literal at the top of their subclass get the
// expected namespace. Do NOT mutate `name` at runtime; the new value
// won't reach the compositor.
PanelWindow {
    id: root
    property string name: ""

    WlrLayershell.namespace:
        root.name !== "" ? "arche-" + root.name : "arche-shell"
}
