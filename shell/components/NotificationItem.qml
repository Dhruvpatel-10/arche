import QtQuick
import ".."

Rectangle {
    id: root
    required property var entry

    function relativeTime(ms) {
        const diff = Math.max(0, Date.now() - ms)
        const m = Math.floor(diff / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + "m ago"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h ago"
        return Math.floor(h / 24) + "d ago"
    }

    function defaultAction() {
        // Remove first so the UI updates instantly; satty's cold start then
        // happens in the background without the panel feeling stuck.
        const appName = entry.appName
        const appIcon = entry.appIcon
        const body = entry.body
        Notifs.removeFromHistory(entry)
        Notifs.invokeDefault(appName, appIcon, body)
    }

    implicitHeight: 58
    color: hoverArea.containsMouse ? Theme.tileBgActive : Theme.tileBg
    radius: Theme.radiusTile
    opacity: entry.dismissed ? 0.55 : 1.0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        // Exclude the X button region (24 width + 12 Row rightMargin = 36)
        // so clicks on X don't bleed into the body's default-action handler.
        anchors.rightMargin: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.modifiers & Qt.MetaModifier) {
                Notifs.removeFromHistory(root.entry)
            } else {
                root.defaultAction()
            }
        }
    }

    Row {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 10

        Rectangle {
            width: 36; height: 36; radius: 18
            color: Theme.bgAlt
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "\uf0f3"
                color: Theme.fg
                font { family: Theme.fontMono; pixelSize: Theme.fontLabel }
            }
        }

        Column {
            width: parent.width - 36 - 10 - 24 - 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.entry.summary
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
                elide: Text.ElideRight; width: parent.width
            }
            Text {
                text: root.entry.body
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                elide: Text.ElideRight; width: parent.width
                visible: text.length > 0
            }
            Text {
                text: (root.entry.appName || "")
                      + (root.entry.appName ? " · " : "")
                      + root.relativeTime(root.entry.time)
                color: Theme.fgDim
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                elide: Text.ElideRight; width: parent.width
            }
        }

        IconButton {
            width: 24; height: 24; radius: 12
            icon: "\uf00d"; iconSize: 9
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Notifs.removeFromHistory(root.entry)
        }
    }
}
