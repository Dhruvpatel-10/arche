import QtQuick
import Quickshell.Services.UPower
import ".."

// BatteryRow — surfaces the primary battery (UPower.displayDevice):
// state icon, percent, and time-to-full/time-to-empty. Hides itself on
// desktops / systems with no battery. Sits between the stat cards and
// the media card.
Rectangle {
    id: root
    readonly property var dev: UPower.displayDevice
    visible: dev.isPresent

    implicitHeight: 56
    color: Theme.bgAlt
    radius: Theme.radiusTile

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
    readonly property color tint: pct < 15 ? Theme.critical
                                  : pct < 30 ? Theme.warn
                                              : Theme.fg

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
            left: parent.left;  leftMargin: 14
            right: parent.right; rightMargin: 14
            verticalCenter: parent.verticalCenter
        }
        spacing: 12

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 17
            color: root.charging ? Theme.accent : Theme.tileBg
            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: root.charging ? Theme.bgAlt : root.tint
                font { family: Theme.fontMono; pixelSize: Theme.fontBody }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 34 - 12 - pctText.width - 12
            spacing: 2
            Text {
                text: "Battery"
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.timeStr
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
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
                family: Theme.fontSans
                pixelSize: Theme.fontLabel
                weight: Font.DemiBold
                features: { "tnum": 1 }
            }
        }
    }
}
