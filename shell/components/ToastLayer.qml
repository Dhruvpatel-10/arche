import QtQuick
import Quickshell
import ".."

StyledWindow {
    id: root
    name: "toasts"
    visible: Notifs.toasts.length > 0
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 6; right: 10 }
    // Size the surface to exactly the content so Hyprland's layer blur
    // (on namespace quickshell) doesn't halo transparent padding.
    implicitWidth: list.width
    implicitHeight: Math.min(list.implicitHeight, 500)
    color: "transparent"
    exclusiveZone: 0

    Column {
        id: list
        anchors.left: parent.left
        anchors.top: parent.top
        width: 344
        spacing: 8

        Repeater {
            model: Notifs.toasts
            delegate: Toast {
                required property var modelData
                notification: modelData
                width: list.width
            }
        }
    }
}
