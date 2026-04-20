import QtQuick
import Quickshell
import ".."
import "../theme"

// ToastLayer — top-right layer surface that stacks active notification
// toasts. Sized to exactly its content so Hyprland's default blur rule
// never halos transparent padding.
StyledWindow {
    id: root
    name: "toasts"
    visible: Notifs.toasts.length > 0
    anchors { top: true; right: true }
    margins {
        top: Sizing.barHeight + Spacing.sm   // bar height + small gap
        right: Spacing.md
    }
    implicitWidth: list.width
    implicitHeight: Math.min(list.implicitHeight, Sizing.px(500))
    color: "transparent"
    exclusiveZone: 0

    Column {
        id: list
        anchors.left: parent.left
        anchors.top: parent.top
        width: Sizing.px(344)
        spacing: Spacing.smMd   // matches NotificationsList rhythm

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
