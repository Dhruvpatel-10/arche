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
// Without a name, the default "arche-shell" namespace matches everything
// the shell paints.
PanelWindow {
    id: root
    property string name: ""

    WlrLayershell.namespace:
        root.name !== "" ? "arche-" + root.name : "arche-shell"
}
