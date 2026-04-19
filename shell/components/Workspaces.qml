import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

Item {
    id: root

    property int shown: 5
    property int dotSize: 6
    property int activeWidth: 18
    property int spacing: 10

    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1

    function isOccupied(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id)
        return !!ws && (ws.toplevels?.values?.length ?? 0) > 0
    }

    implicitWidth: row.implicitWidth
    implicitHeight: dotSize + 8

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing

        Repeater {
            model: root.shown

            Item {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool occupied: root.isOccupied(wsId)

                width: isActive ? root.activeWidth : root.dotSize
                height: root.dotSize
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: cell.isActive
                           ? Theme.accent
                           : (cell.occupied ? Theme.fg : "transparent")
                    border.color: cell.occupied || cell.isActive ? "transparent" : Theme.fgDim
                    border.width: cell.occupied || cell.isActive ? 0 : 1
                    opacity: cell.isActive ? 1.0 : (cell.occupied ? 0.85 : 0.55)

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${cell.wsId}`)
                }
            }
        }
    }

    WheelHandler {
        target: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const dir = event.angleDelta.y > 0 ? -1 : 1
            const next = Math.min(root.shown, Math.max(1, root.activeId + dir))
            if (next !== root.activeId) Hyprland.dispatch(`workspace ${next}`)
            event.accepted = true
        }
    }
}
