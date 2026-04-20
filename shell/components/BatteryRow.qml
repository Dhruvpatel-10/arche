import QtQuick
import Quickshell.Services.UPower
import "../theme"

// BatteryRow — surfaces the primary battery (UPower.displayDevice):
// state icon, percent, and time-to-full/time-to-empty. Hides itself on
// desktops / systems with no battery. Sits between the stat cards and
// the media card in the control-center drawer.
Rectangle {
    id: root
    readonly property var dev: UPower.displayDevice
    visible: dev.isPresent

    implicitHeight: Sizing.px(56)
    color: Colors.bgAlt
    radius: Shape.radiusTile

    readonly property real pct:     (dev.percentage ?? 0) * 100
    readonly property int  state:   dev.state ?? 0
    readonly property bool charging: state === UPowerDeviceState.Charging
                                     || state === UPowerDeviceState.PendingCharge
    readonly property bool onAC:     state === UPowerDeviceState.FullyCharged

    // "fa-bolt" when charging, "fa-plug" when full on AC, else a static
    // battery glyph. Color tracks critical/warn thresholds.
    readonly property string glyph: charging ? "\uf0e7"
                                    : onAC    ? "\uf1e6"
                                              : "\uf240"
    readonly property color tint: pct < 15 ? Colors.critical
                                  : pct < 30 ? Colors.warn
                                              : Colors.fg

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
            const t = root._formatSecs(root.dev.timeToFull)
            return t.length > 0 ? t + " to full" : "Charging"
        }
        const t = root._formatSecs(root.dev.timeToEmpty)
        return t.length > 0 ? t + " remaining" : "On battery"
    }

    Row {
        anchors {
            left: parent.left;   leftMargin: Spacing.lg - 2   // 14 px
            right: parent.right; rightMargin: Spacing.lg - 2
            verticalCenter: parent.verticalCenter
        }
        spacing: Spacing.md

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Sizing.px(34)
            height: Sizing.px(34)
            radius: width / 2
            color: root.charging ? Colors.accent : Colors.tileBg
            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: root.charging ? Colors.bgAlt : root.tint
                font { family: Typography.fontMono; pixelSize: Typography.fontBody }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Sizing.px(34) - Spacing.md
                   - pctText.width - Spacing.md
            spacing: 2
            Text {
                text: "Battery"
                color: Colors.fg
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontBody
                    weight: Font.DemiBold
                }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.timeStr
                color: Colors.fgMuted
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Text {
            id: pctText
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.pct) + "%"
            color: root.tint
            font {
                family: Typography.fontSans
                pixelSize: Typography.fontLabel
                weight: Font.DemiBold
                features: { "tnum": 1 }
            }
        }
    }
}
