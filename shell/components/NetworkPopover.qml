import QtQuick
import Quickshell
import ".."
import "../services"
import "../theme"

// NetworkPopover — focused popover for the wifi pill. Radio toggle, the
// current connection (with Disconnect), a scanned list of nearby SSIDs
// with signal bars, a Rescan action, and an escape hatch to impala for
// anything beyond quick-join.
//
// Scan semantics: `Net.scan()` runs once when the popover opens and
// refreshes on Rescan. We don't poll continuously — that'd hammer nmcli
// for no visible benefit while the drawer is closed.
WingPopover {
    id: root
    popoverId: "net"
    name:      "popover-net"

    cardWidth:         Sizing.px(340)
    anchorRightMargin: Sizing.px(170)   // roughly under the wifi pill

    property var modelData
    screen: modelData

    // Kick a scan when the popover opens. Connections stays at the
    // WingPopover scope — it's not a visual item.
    Connections {
        target: Ui
        function onRightPopoverChanged() {
            if (Ui.rightPopover === "net" && Net.radioOn) Net.scan()
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
                    text: Net.radioOn
                          ? (Net.connected ? "\uf1eb" : "\uf519")
                          : "\uf6ac"
                    color: Net.radioOn ? Colors.accent : Colors.fgMuted
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightDemiBold
                }
            }

            // ─── Radio toggle row ─────────────────────────────────────
            Rectangle {
                width: parent.width
                height: Sizing.px(38)
                radius: Shape.radiusSm
                color: radioMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
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
                        text: Net.radioOn ? "On" : "Off"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                        width: parent.width - pill.width - parent.spacing
                    }

                    Rectangle {
                        id: pill
                        anchors.verticalCenter: parent.verticalCenter
                        width: Sizing.px(32); height: Sizing.px(16)
                        radius: height / 2
                        color: Net.radioOn ? Colors.accent : Colors.bgAlt
                        border.color: Colors.border
                        border.width: Shape.borderThin
                        Behavior on color { CAnim { type: "fast" } }
                        Rectangle {
                            x: Net.radioOn ? parent.width - width - Sizing.px(2)
                                           : Sizing.px(2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(12); height: Sizing.px(12)
                            radius: width / 2
                            color: Net.radioOn ? Colors.bgAlt : Colors.fgMuted
                            Behavior on x { Anim { type: "fast" } }
                        }
                    }
                }

                MouseArea {
                    id: radioMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.toggle()
                }
            }

            // ─── Current connection ───────────────────────────────────
            Rectangle {
                width: parent.width
                visible: Net.connected
                height: visible ? connRow.implicitHeight + Spacing.md * 2 : 0
                radius: Shape.radiusSm
                color: Colors.bgSurface
                border.color: Colors.border
                border.width: Shape.borderThin

                Row {
                    id: connRow
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Spacing.md
                    anchors.right: parent.right
                    anchors.rightMargin: Spacing.md
                    spacing: Spacing.sm

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf1eb"
                        color: Colors.accent
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontLabel
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        width: connRow.width
                               - 2 * Spacing.sm
                               - disconnectBtn.width
                               - Sizing.px(20)
                        Text {
                            text: Net.ssid
                            color: Colors.fg
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontCaption
                            font.weight: Typography.weightMedium
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: "Connected"
                            color: Colors.success
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                        }
                    }
                    Rectangle {
                        id: disconnectBtn
                        anchors.verticalCenter: parent.verticalCenter
                        width: Sizing.px(86); height: Sizing.px(24)
                        radius: height / 2
                        color: discMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                        Behavior on color { CAnim { type: "fast" } }
                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            color: Colors.fg
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                        }
                        MouseArea {
                            id: discMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Net.disconnect()
                        }
                    }
                }
            }

            // ─── Nearby networks header row ───────────────────────────
            Row {
                width: parent.width
                visible: Net.radioOn
                spacing: Spacing.sm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nearby networks"
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    font.weight: Typography.weightMedium
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: rescanRow.implicitWidth + Spacing.md
                    height: Sizing.px(20)
                    radius: height / 2
                    color: rescanMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                    Behavior on color { CAnim { type: "fast" } }
                    Row {
                        id: rescanRow
                        anchors.centerIn: parent
                        spacing: Sizing.px(4)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf021"
                            color: Colors.fg
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            NumberAnimation on rotation {
                                running: Net.scanning
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 900
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Rescan"
                            color: Colors.fg
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                        }
                    }
                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Net.rescan()
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Sizing.px(4)
                visible: Net.radioOn

                Rectangle {
                    width: parent.width
                    height: Sizing.px(38)
                    radius: Shape.radiusSm
                    color: Colors.tileBg
                    visible: Net.scanList.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: Net.scanning ? "Scanning…" : "No networks found"
                        color: Colors.fgMuted
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                    }
                }

                Repeater {
                    model: Net.scanList.slice(0, 8)
                    delegate: Rectangle {
                        id: scanRow
                        required property var modelData
                        readonly property bool isSecure:
                            modelData.security && modelData.security !== "--"
                        readonly property bool isActive:
                            modelData.inUse || (Net.connected && modelData.ssid === Net.ssid)
                        width: body.width
                        height: Sizing.px(34)
                        radius: Shape.radiusSm
                        color: rowMouse.containsMouse
                               ? Colors.tileBgActive
                               : (isActive ? Colors.bgSurface : "transparent")
                        Behavior on color { CAnim { type: "fast" } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Spacing.sm
                            anchors.right: parent.right
                            anchors.rightMargin: Spacing.sm
                            spacing: Spacing.sm

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.signal > 66
                                      ? "\uf1eb"
                                      : (modelData.signal > 33 ? "\uf6aa" : "\uf6ab")
                                color: isActive ? Colors.accent : Colors.fg
                                font.family: Typography.fontMono
                                font.pixelSize: Typography.fontCaption
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.ssid
                                color: Colors.fg
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontCaption
                                font.weight: isActive
                                             ? Typography.weightDemiBold
                                             : Typography.weightNormal
                                elide: Text.ElideRight
                                width: body.width - Spacing.sm * 4
                                       - Sizing.px(40) - Sizing.px(16) - Sizing.px(14)
                            }
                            Item { width: 1; height: 1 }
                            Text {
                                visible: scanRow.isSecure
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\uf023"
                                color: Colors.fgMuted
                                font.family: Typography.fontMono
                                font.pixelSize: Typography.fontMicro
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.signal + ""
                                color: Colors.fgMuted
                                font.family: Typography.fontMono
                                font.pixelSize: Typography.fontMicro
                                font.features: ({ "tnum": 1 })
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.isActive) return
                                Net.connectTo(modelData.ssid)
                            }
                        }
                    }
                }
            }

            // Connect error surfacing (usually missing creds → use impala)
            Rectangle {
                width: parent.width
                visible: Net.connectError.length > 0
                height: visible ? errText.implicitHeight + Spacing.md : 0
                radius: Shape.radiusSm
                color: Colors.bgAlt
                border.color: Colors.critical
                border.width: Shape.borderThin
                Text {
                    id: errText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Spacing.sm
                    anchors.rightMargin: Spacing.sm
                    text: Net.connectError
                    color: Colors.critical
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    wrapMode: Text.WordWrap
                }
            }

            // ─── Escape hatch → impala ────────────────────────────────
            Rectangle { width: parent.width; height: 1; color: Colors.border; opacity: 0.5 }
            Rectangle {
                width: parent.width
                height: Sizing.px(34)
                radius: Shape.radiusSm
                color: impalaMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
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
                        text: "Open impala"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                    }
                }
                MouseArea {
                    id: impalaMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.closePopover()
                        Quickshell.execDetached(["arche-popup", "impala"])
                    }
                }
            }
        }
    }
}
