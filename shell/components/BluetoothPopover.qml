import QtQuick
import Quickshell
import ".."
import "../services"
import "../theme"

// BluetoothPopover — focused popover for the BT pill. Adapter toggle,
// currently-connected device banner, paired devices list with
// connect/disconnect, escape hatch to bluetui.
//
// Scanning for *new* devices is intentionally not here — bluetoothctl's
// discovery flow is slow and interactive. The popover manages paired
// devices well; new pairings go through bluetui.
WingPopover {
    id: root
    popoverId: "bt"
    name:      "popover-bt"

    cardWidth:         Sizing.px(340)
    anchorRightMargin: Sizing.px(140)   // roughly under the BT pill

    property var modelData
    screen: modelData

    // Refresh paired devices on open. Connections is non-visual; leaving
    // it at the WingPopover scope is safe.
    Connections {
        target: Ui
        function onRightPopoverChanged() {
            if (Ui.rightPopover === "bt" && Bt.powered) Bt.refreshDevices()
        }
    }

    contentComponent: Component {
        Column {
            id: body
            width: parent.width
            spacing: Spacing.md

            // ─── Header ───────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: Spacing.sm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bt.powered ? "\uf293" : "\uf294"
                    color: Bt.powered ? Colors.accentAlt : Colors.fgMuted
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightDemiBold
                }
            }

            // ─── Adapter toggle ───────────────────────────────────────
            Rectangle {
                width: parent.width
                height: Sizing.px(38)
                radius: Shape.radiusSm
                color: adapterMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                Behavior on color { CAnim { type: "fast" } }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Spacing.md
                    anchors.right: parent.right
                    anchors.rightMargin: Spacing.md
                    spacing: Spacing.sm
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Bt.powered ? "On" : "Off"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                        width: parent.width - btPill.width - parent.spacing
                    }
                    Rectangle {
                        id: btPill
                        anchors.verticalCenter: parent.verticalCenter
                        width: Sizing.px(32); height: Sizing.px(16)
                        radius: height / 2
                        color: Bt.powered ? Colors.accentAlt : Colors.bgAlt
                        border.color: Colors.border
                        border.width: Shape.borderThin
                        Behavior on color { CAnim { type: "fast" } }
                        Rectangle {
                            x: Bt.powered ? parent.width - width - Sizing.px(2)
                                          : Sizing.px(2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(12); height: Sizing.px(12)
                            radius: width / 2
                            color: Bt.powered ? Colors.bgAlt : Colors.fgMuted
                            Behavior on x { Anim { type: "fast" } }
                        }
                    }
                }
                MouseArea {
                    id: adapterMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bt.toggle()
                }
            }

            // ─── Devices list ─────────────────────────────────────────
            Row {
                width: parent.width
                visible: Bt.powered
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Paired devices"
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    font.weight: Typography.weightMedium
                }
            }

            Column {
                width: parent.width
                spacing: Sizing.px(4)
                visible: Bt.powered

                Rectangle {
                    width: parent.width
                    height: Sizing.px(38)
                    radius: Shape.radiusSm
                    color: Colors.tileBg
                    visible: Bt.devices.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "No paired devices"
                        color: Colors.fgMuted
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                    }
                }

                Repeater {
                    model: Bt.devices
                    delegate: Rectangle {
                        required property var modelData
                        width: body.width
                        height: Sizing.px(38)
                        radius: Shape.radiusSm
                        color: rowMouse.containsMouse
                               ? Colors.tileBgActive
                               : (modelData.connected ? Colors.bgSurface : "transparent")
                        Behavior on color { CAnim { type: "fast" } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.sm
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.sm
                            spacing: Spacing.sm

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Sizing.px(6); height: Sizing.px(6)
                                radius: width / 2
                                color: modelData.connected ? Colors.success : Colors.fgDim
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: Colors.fg
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontCaption
                                font.weight: modelData.connected
                                             ? Typography.weightDemiBold
                                             : Typography.weightNormal
                                elide: Text.ElideRight
                                width: body.width - Spacing.sm * 4
                                       - Sizing.px(6)
                                       - actionLabel.implicitWidth
                            }
                            Item { width: 1; height: 1 }
                            Text {
                                id: actionLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.connected ? "Disconnect" : "Connect"
                                color: modelData.connected ? Colors.critical : Colors.accent
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontMicro
                                font.weight: Typography.weightMedium
                                opacity: rowMouse.containsMouse ? 1 : 0.7
                                Behavior on opacity { Anim { type: "fast" } }
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected)
                                    Bt.disconnectDevice(modelData.mac)
                                else
                                    Bt.connectDevice(modelData.mac)
                            }
                        }
                    }
                }
            }

            // Error surfacing (e.g. device unreachable)
            Rectangle {
                width: parent.width
                visible: Bt.lastError.length > 0
                height: visible ? btErr.implicitHeight + Spacing.md : 0
                radius: Shape.radiusSm
                color: Colors.bgAlt
                border.color: Colors.critical
                border.width: Shape.borderThin
                Text {
                    id: btErr
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Spacing.sm
                    anchors.rightMargin: Spacing.sm
                    text: Bt.lastError
                    color: Colors.critical
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    wrapMode: Text.WordWrap
                }
            }

            // ─── Escape hatch → bluetui ───────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Colors.border; opacity: 0.5 }
            Rectangle {
                width: parent.width
                height: Sizing.px(34)
                radius: Shape.radiusSm
                color: bluetuiMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                Behavior on color { CAnim { type: "fast" } }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Spacing.md
                    spacing: Spacing.sm
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf013"
                        color: Colors.fg
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontCaption
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open bluetui"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                    }
                }
                MouseArea {
                    id: bluetuiMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.closePopover()
                        Quickshell.execDetached(["arche-popup", "bluetui"])
                    }
                }
            }
        }
    }
}
