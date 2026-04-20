import QtQuick
import ".."
import "../theme"

// NotificationsList — history column rendered inside the control-center
// drawer. A title row with a "Clear All" pill on the right, then one
// NotificationItem per entry. When empty, shows a scaled fade-in
// illustration (Caelestia /tmp/shell modules/launcher/ContentList.qml
// pattern) so the drawer reads as "caught up", not "broken".
Column {
    id: root
    spacing: Spacing.smMd   // one step denser than `md` between rows

    readonly property bool isEmpty: Notifs.history.length === 0

    Row {
        width: parent.width
        height: clearBtn.height   // locks row height so verticalCenter works
        Text {
            text: "Notifications"
            color: Colors.fg
            font {
                family: Typography.fontSans
                pixelSize: Typography.fontBody
                weight: Font.DemiBold
            }
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - clearBtn.width
        }
        Rectangle {
            id: clearBtn
            width: Sizing.px(72)
            height: Sizing.px(24)
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.tileBg
            visible: !root.isEmpty
            clip: true

            StateLayer {
                anchors.fill: parent
                source: clearMouse
                tint: Colors.fg
            }

            Text {
                anchors.centerIn: parent
                text: "Clear All"
                color: Colors.fg
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontCaption
                    weight: Font.Medium
                }
            }
            MouseArea {
                id: clearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearHistory()
            }
        }
    }

    Repeater {
        model: Notifs.history
        delegate: NotificationItem {
            required property var modelData
            entry: modelData
            width: root.width
        }
    }

    // Empty state. Scaled fade-in so the drawer still feels alive when
    // there's nothing in the list. Muted tone reads as "absence of
    // content" rather than as a placeholder card.
    Item {
        width: parent.width
        height: Sizing.px(84)
        visible: root.isEmpty
        opacity: root.isEmpty ? 1 : 0
        scale:   root.isEmpty ? 1 : 0.5
        Behavior on opacity { Anim { type: "standard" } }
        Behavior on scale   { Anim { type: "spatial" } }

        Column {
            anchors.centerIn: parent
            spacing: Spacing.xs

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf0f3"    // bell
                color: Colors.fgDim
                font { family: Typography.fontMono; pixelSize: Typography.fontDisplay }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: Colors.fgMuted
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontBody
                    weight: Font.DemiBold
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "You're all caught up"
                color: Colors.fgDim
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
            }
        }
    }
}
