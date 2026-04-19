import QtQuick
import Quickshell.Services.Notifications
import ".."

Rectangle {
    id: root
    required property Notification notification

    function defaultAction() {
        const appName = notification.appName
        const appIcon = notification.appIcon
        const body = notification.body
        notification.dismiss()
        Notifs.invokeDefault(appName, appIcon, body)
    }

    implicitHeight: Math.max(58, col.implicitHeight + 20)
    color: Theme.card
    radius: Theme.radiusTile
    border.color: Theme.border
    border.width: 1

    opacity: 0
    transform: Translate { id: slide; x: 40 }

    Component.onCompleted: {
        opacity = 1
        slide.x = 0
    }

    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on transform { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Row {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 10

        Rectangle {
            width: 36; height: 36; radius: 18
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "\uf0f3"
                color: Theme.bgAlt
                font { family: Theme.fontMono; pixelSize: Theme.fontLabel }
            }
        }

        Column {
            id: col
            width: parent.width - 36 - 10 - 24 - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: root.notification.summary
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                visible: text.length > 0
                text: root.notification.body
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.notification.appName
                color: Theme.fgDim
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                width: parent.width
                elide: Text.ElideRight
            }
        }

        IconButton {
            width: 24; height: 24; radius: 12
            color: "transparent"
            icon: "\uf00d"; iconSize: 9
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.notification.dismiss()
        }
    }

    MouseArea {
        anchors.fill: parent
        // Exclude the X button region so clicks on X don't also trigger the
        // default action (e.g. accidentally launching satty on dismiss).
        anchors.rightMargin: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.modifiers & Qt.MetaModifier) {
                root.notification.dismiss()
            } else {
                root.defaultAction()
            }
        }
    }
}
