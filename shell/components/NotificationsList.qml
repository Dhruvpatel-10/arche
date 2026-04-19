import QtQuick
import ".."

Column {
    id: root
    spacing: 8

    readonly property bool isEmpty: Notifs.history.length === 0

    Row {
        width: parent.width
        height: clearBtn.height   // locks row height so verticalCenter works
        Text {
            text: "Notifications"
            color: Theme.fg
            font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - clearBtn.width
        }
        Rectangle {
            id: clearBtn
            width: 72; height: 24; radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.tileBg
            visible: !root.isEmpty
            clip: true

            StateLayer {
                anchors.fill: parent
                source: clearMouse
                tint: Theme.fg
            }

            Text {
                anchors.centerIn: parent
                text: "Clear All"
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption; weight: Font.Medium }
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

    // Empty state — Caelestia /tmp/shell modules/launcher/ContentList.qml
    // pattern: scaled fade-in illustration + two-line label. Muted tone
    // matches fgMuted/fgDim so it reads as "absence of content" rather
    // than as a placeholder card.
    Item {
        width: parent.width
        height: 84
        visible: root.isEmpty
        opacity: root.isEmpty ? 1 : 0
        scale:   root.isEmpty ? 1 : 0.5
        Behavior on opacity { Anim { type: "standard" } }
        Behavior on scale   { Anim { type: "spatial" } }

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\uf0f3"    // bell
                color: Theme.fgDim
                font { family: Theme.fontMono; pixelSize: Theme.fontSizeXL }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "You're all caught up"
                color: Theme.fgDim
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
            }
        }
    }
}
