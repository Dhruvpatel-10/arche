import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."
import "../theme"

// BatteryPopover — focused popover for the battery pill. Three bands:
//
//   1. Battery hero — big percent + state + time remaining
//   2. Power profile selector — reads /sys/firmware/acpi/platform_profile,
//      write goes through arche-legion (which holds the sudo/polkit path)
//   3. Session row — Lock / Sleep / Logout / Power menu
//
// Platform profile: we read sysfs directly (user-readable) but do not
// attempt to write. The `low-power / balanced / performance` chips are
// display + shortcut-to-arche-legion. Writing sysfs needs root; solving
// that belongs in scripts/ (polkit rule), not here.
WingPopover {
    id: root
    popoverId: "battery"
    name:      "popover-battery"

    cardWidth:         Sizing.px(320)
    anchorRightMargin: Sizing.px(12)   // rightmost pill, flush with the edge

    property var modelData
    screen: modelData

    // ─── Platform profile polling (non-visual) ──────────────────────
    property string platformProfile: ""
    property var platformProfileChoices: []

    Process {
        id: readProfile
        command: ["cat", "/sys/firmware/acpi/platform_profile"]
        stdout: StdioCollector {
            onStreamFinished: root.platformProfile = text.trim()
        }
    }
    Process {
        id: readChoices
        command: ["cat", "/sys/firmware/acpi/platform_profile_choices"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.platformProfileChoices = text.trim().split(/\s+/)
                    .filter(c => ["low-power", "balanced", "performance"]
                                 .indexOf(c) >= 0)
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.shouldBeActive
        triggeredOnStart: true
        onTriggered: {
            readProfile.running = true
            if (root.platformProfileChoices.length === 0)
                readChoices.running = true
        }
    }

    // ─── Battery helpers (same derivation as BatteryRow) ────────────
    readonly property var dev: UPower.displayDevice
    readonly property real pct: (dev?.percentage ?? 0) * 100
    readonly property int devState: dev?.state ?? 0
    readonly property bool charging:
        devState === UPowerDeviceState.Charging
        || devState === UPowerDeviceState.PendingCharge
    readonly property bool onAC: devState === UPowerDeviceState.FullyCharged

    function _formatSecs(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }
    readonly property string timeStr: {
        if (onAC) return "Full"
        if (charging) {
            const t = root._formatSecs(dev?.timeToFull ?? 0)
            return t ? t + " to full" : "Charging"
        }
        const t = root._formatSecs(dev?.timeToEmpty ?? 0)
        return t ? t + " remaining" : "On battery"
    }

    readonly property color battTint: pct < 15 ? Colors.critical
                                      : pct < 30 ? Colors.warn
                                                  : Colors.fg

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
                    text: root.charging ? "\uf0e7"
                          : root.onAC    ? "\uf1e6"
                                         : "\uf240"
                    color: root.charging ? Colors.success : root.battTint
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.dev?.isPresent ? "Battery" : "Power"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightDemiBold
                }
            }

            // ─── Hero: big percent + state ───────────────────────────
            Rectangle {
                width: parent.width
                height: Sizing.px(84)
                radius: Shape.radiusNormal
                color: Colors.bgSurface
                border.color: Colors.border
                border.width: Shape.borderThin
                visible: root.dev?.isPresent ?? false

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Spacing.lg
                    anchors.rightMargin: Spacing.lg
                    spacing: Spacing.md

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Sizing.px(32); height: Sizing.px(16)
                        radius: Sizing.px(3)
                        color: "transparent"
                        border.color: Colors.fgMuted
                        border.width: Shape.borderThin
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: Sizing.px(2)
                            width: Math.max(0,
                                   (parent.width - Sizing.px(4)) * (root.pct / 100))
                            radius: Sizing.px(2)
                            color: root.charging ? Colors.success
                                  : (root.pct < 15 ? Colors.critical : Colors.fg)
                            Behavior on width { Anim { type: "fast" } }
                        }
                        Rectangle {
                            anchors.left: parent.right
                            anchors.leftMargin: Sizing.px(1)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(2); height: Sizing.px(6)
                            radius: Sizing.px(1)
                            color: Colors.fgMuted
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: Math.round(root.pct) + "%"
                            color: root.battTint
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontDisplay
                            font.weight: Typography.weightDemiBold
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            text: root.timeStr
                            color: Colors.fgMuted
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontCaption
                        }
                    }
                }
            }

            // ─── AC-only fallback when no battery is present ─────────
            Rectangle {
                visible: !(root.dev?.isPresent ?? false)
                width: parent.width
                height: Sizing.px(48)
                radius: Shape.radiusSm
                color: Colors.bgSurface
                Text {
                    anchors.centerIn: parent
                    text: "Desktop power"
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontCaption
                }
            }

            // ─── Power profile selector ──────────────────────────────
            Column {
                width: parent.width
                spacing: Spacing.xs
                visible: root.platformProfileChoices.length > 0

                Text {
                    text: "Power profile"
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    font.weight: Typography.weightMedium
                }

                Row {
                    width: parent.width
                    spacing: Sizing.px(6)
                    Repeater {
                        model: root.platformProfileChoices
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active:
                                modelData === root.platformProfile
                            width: (body.width - Sizing.px(12)) / 3
                            height: Sizing.px(40)
                            radius: Shape.radiusSm
                            color: active ? Colors.tileBgActive
                                   : (profMouse.containsMouse ? Colors.tileBg
                                                              : "transparent")
                            border.color: active ? Colors.accent : Colors.border
                            border.width: Shape.borderThin
                            Behavior on color { CAnim { type: "fast" } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData === "low-power" ? "\uf06c"
                                          : (modelData === "performance" ? "\uf0e7"
                                                                         : "\uf042")
                                    color: active ? Colors.accent : Colors.fg
                                    font.family: Typography.fontMono
                                    font.pixelSize: Typography.fontCaption
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData === "low-power" ? "Saver"
                                          : (modelData === "performance" ? "Perf"
                                                                         : "Bal")
                                    color: active ? Colors.accent : Colors.fg
                                    font.family: Typography.fontSans
                                    font.pixelSize: Typography.fontMicro
                                    font.weight: active ? Typography.weightDemiBold
                                                        : Typography.weightNormal
                                }
                            }
                            MouseArea {
                                id: profMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // sysfs write requires root; defer to the legion
                                // TUI which already owns the sudo path.
                                onClicked: {
                                    Ui.closePopover()
                                    Quickshell.execDetached(["arche-popup", "arche-legion"])
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.border; opacity: 0.5 }

            // ─── Session row ──────────────────────────────────────────
            Row {
                width: parent.width
                spacing: Sizing.px(6)

                Repeater {
                    model: [
                        { id: "lock",     icon: "\uf023", label: "Lock",   tint: "fg"       },
                        { id: "sleep",    icon: "\uf186", label: "Sleep",  tint: "fg"       },
                        { id: "logout",   icon: "\uf2f5", label: "Logout", tint: "fg"       },
                        { id: "powermenu", icon: "\uf011", label: "Power", tint: "critical" },
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (body.width - Sizing.px(18)) / 4
                        height: Sizing.px(54)
                        radius: Shape.radiusSm
                        color: sessMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                        Behavior on color { CAnim { type: "fast" } }

                        Column {
                            anchors.centerIn: parent
                            spacing: Sizing.px(4)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                color: modelData.tint === "critical"
                                       ? Colors.critical : Colors.fg
                                font.family: Typography.fontMono
                                font.pixelSize: Typography.fontLabel
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                color: modelData.tint === "critical"
                                       ? Colors.critical : Colors.fg
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontMicro
                                font.weight: Typography.weightMedium
                            }
                        }
                        MouseArea {
                            id: sessMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Ui.closePopover()
                                switch (modelData.id) {
                                    case "lock":
                                        PowerMenu.run(PowerMenu.actions.find(a => a.id === "lock"))
                                        break
                                    case "sleep":
                                        PowerMenu.run(PowerMenu.actions.find(a => a.id === "sleep"))
                                        break
                                    case "logout":
                                        PowerMenu.run(PowerMenu.actions.find(a => a.id === "logout"))
                                        break
                                    case "powermenu":
                                        PowerMenu.show()
                                        break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
