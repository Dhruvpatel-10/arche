import QtQuick
import ".."
import "../theme"

// NotificationsPopover — focused popover for the bell pill. Reuses the
// existing NotificationsList for parity with the in-bar-drawer history,
// minus the ControlCenter chrome (clock, toggles, stats). Clicking the
// bell toggles it; outside-click / moving to another monitor dismisses
// via WingPopover's shared plumbing.
WingPopover {
    popoverId: "notifs"
    name:      "popover-notifs"

    cardWidth:         Sizing.px(380)
    anchorRightMargin: Sizing.px(12)

    property var modelData
    screen: modelData

    contentComponent: Component {
        Column {
            width: parent.width
            spacing: Spacing.md

            Row {
                width: parent.width
                spacing: Spacing.sm

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0f3"
                    color: Colors.accent
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightDemiBold
                }
            }

            Rectangle {
                width: parent.width; height: 1
                color: Colors.border; opacity: 0.5
            }

            NotificationsList { width: parent.width }
        }
    }
}
