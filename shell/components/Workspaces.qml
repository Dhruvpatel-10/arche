import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

// Workspaces — row of dots showing workspace state. Active one stretches
// into a pill; occupied workspaces are filled, empty ones are outlined.
// Scroll to move between workspaces, click to jump.
//
// Motion: width/color/opacity animate through the shared Anim / CAnim
// presets so the motion language stays consistent with the rest of the
// bar. No bespoke durations.
Item {
    id: root

    property int shown: 5
    property int dotSize: Sizing.px(6)
    property int activeWidth: Sizing.px(18)
    property int spacing: Spacing.md

    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1

    function isOccupied(id) {
        const ws = Hyprland.workspaces.values.find(w => w.id === id)
        return !!ws && (ws.toplevels?.values?.length ?? 0) > 0
    }

    implicitWidth: row.implicitWidth
    implicitHeight: dotSize + Spacing.smMd

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

                // Pill-stretch eases via the shared `standard` preset.
                Behavior on width { Anim { type: "standard" } }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: cell.isActive
                           ? Colors.accent
                           : (cell.occupied ? Colors.fg : "transparent")
                    border.color: cell.occupied || cell.isActive
                                  ? "transparent"
                                  : Colors.fgDim
                    border.width: cell.occupied || cell.isActive ? 0 : 1
                    opacity: cell.isActive ? 1.0 : (cell.occupied ? 0.85 : 0.55)

                    Behavior on color   { CAnim { type: "fast" } }
                    Behavior on opacity { Anim  { type: "fast" } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Spacing.sm
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
