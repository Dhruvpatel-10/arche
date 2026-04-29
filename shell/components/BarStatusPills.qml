import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."
import "../services"
import "../theme"

// BarStatusPills — right cluster of the unified Bar. Factored out of the
// old BarRightWing so Bar.qml stays readable. Unboxed pills, three
// ordered groups separated by thin vertical rules:
//
//   [ ● REC 00:12 ] · Notifications · Connectivity · Power
//
// Recording pill only renders when `Ui.recording` is true. All glyphs
// use BMP codepoints verified present in MesloLGS Nerd Font (see the
// old BarRightWing header) so the compositor never falls through to a
// CJK substitute.
//
// Vertical rhythm contract:
//   pill height:   Sizing.px(22)           (set on each WingPill)
//   icon size:     Typography.fontLabel    (15)
//   numeral size:  Typography.fontCaption  (12) + tnum
//   cluster gap:   Spacing.sm (6)
//   inter-cluster: 1-px separator + Spacing.sm on each side (natural)
//
// Adaptive foreground: fgPrimary/fgMuted/fgDim flip to the dark-on-light
// palette when the wallpaper is light AND the bar is translucent.
RowLayout {
    id: root

    // ─── Inputs ───────────────────────────────────────────────────────
    property string screenName: ""
    property bool hasFullscreen: false

    // ─── Adaptive foreground selector ─────────────────────────────────
    readonly property bool _useLight: !hasFullscreen && WallpaperContrast.isLight
    readonly property color fgPrimary: _useLight ? Colors.fgOnLight : Colors.fg
    readonly property color fgMuted:   _useLight ? Colors.fgMutedOnLight : Colors.fgMuted
    readonly property color fgDim:     _useLight ? Colors.fgDimOnLight : Colors.fgDim

    spacing: Spacing.sm

    // ─── Idle-lock pill (conditional) ──────────────────────────
    // Visible when auto-lock is enabled (default state). Hidden when
    // paused via `qs ipc call idle off` / SUPER+CTRL+I — its absence
    // signals the override. Click toggles. fgMuted blends with the rest
    // of the cluster — auto-lock-on is the silent default, not a warning.
    WingPill {
        Layout.alignment: Qt.AlignVCenter
        visible: IdleLock.enabled
        onClicked: IdleLock.enabled = !IdleLock.enabled
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: ""  // nf-fa-lock — HAS in MesloLGS, BMP-safe
            color: root.fgMuted
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "standard" } }
        }
    }

    // ─── Recording pill (conditional) ─────────────────────────────────
    WingPill {
        Layout.alignment: Qt.AlignVCenter
        visible: Ui.recording
        Rectangle {
            Layout.preferredWidth: Sizing.pxFor(6, root.screenName)
            Layout.preferredHeight: Sizing.pxFor(6, root.screenName)
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: Colors.critical
            SequentialAnimation on opacity {
                running: Ui.recording
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.35; to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Ui.recordingTime
            color: Colors.critical
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
            font.features: ({ "tnum": 1 })
        }
    }

    // ─── Cluster 1: Notifications ─────────────────────────────────────
    WingPill {
        Layout.alignment: Qt.AlignVCenter
        onClicked: Ui.togglePopover("notifs")
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "\uf0f3"   // nf-fa-bell — HAS in MesloLGS
            color: root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "standard" } }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: (Notifs.history?.length ?? 0)
            color: root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
            font.features: ({ "tnum": 1 })
            Behavior on color { CAnim { type: "standard" } }
        }
    }

    // ─── Cluster separator ────────────────────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Sizing.pxFor(1, root.screenName)
        Layout.preferredHeight: Sizing.pxFor(12, root.screenName)
        color: Colors.separator
        opacity: Effects.opacitySubtle
    }

    // ─── Cluster 2: Connectivity — WiFi · Bluetooth · Volume ──────────
    // WiFi glyph is always \uf1eb (fa-wifi — stable across Nerd Font
    // versions). Color conveys state. The off-glyph U+F6AC is MISSING in
    // MesloLGS and would fall back to a CJK substitute (the old "炉"
    // bug); we render the same glyph and dim it instead.
    WingPill {
        Layout.alignment: Qt.AlignVCenter
        onClicked: Ui.togglePopover("net")
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "\uf1eb"
            color: Net.radioOn
                   ? (Net.connected ? root.fgPrimary : root.fgMuted)
                   : root.fgDim
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "fast" } }
        }
    }

    WingPill {
        Layout.alignment: Qt.AlignVCenter
        onClicked: Ui.togglePopover("bt")
        Text {
            Layout.alignment: Qt.AlignVCenter
            // Both \uf293 (on) and \uf294 (off) HAS in MesloLGS.
            text: Bt.powered ? "\uf293" : "\uf294"
            color: Bt.powered
                   ? (Bt.connected ? root.fgPrimary : root.fgMuted)
                   : root.fgDim
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "fast" } }
        }
    }

    WingPill {
        Layout.alignment: Qt.AlignVCenter
        onClicked: Ui.togglePopover("audio")
        onScrolled: delta => {
            const s = Pipewire.defaultAudioSink?.audio
            if (!s) return
            s.volume = Math.max(0, Math.min(1, s.volume + delta * 0.05))
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            // \uf026 (muted) / \uf028 (high) — both HAS in MesloLGS.
            text: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                  ? "\uf026" : "\uf028"
            color: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                   ? root.fgMuted : root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "fast" } }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
            color: root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
            font.features: ({ "tnum": 1 })
            Behavior on color { CAnim { type: "standard" } }
        }
    }

    // ─── Cluster separator ────────────────────────────────────────────
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Sizing.pxFor(1, root.screenName)
        Layout.preferredHeight: Sizing.pxFor(12, root.screenName)
        color: Colors.separator
        opacity: Effects.opacitySubtle
    }

    // ─── Cluster 3: Power ─────────────────────────────────────────────
    // Battery as a single Nerd Font glyph that swaps with charge level
    // (5 FA stops, all BMP-safe in MesloLGS — same family used by WiFi /
    // BT / Volume so the cluster reads as one rhythm). Color encodes
    // state: critical when low + on battery, success while charging,
    // adaptive fgPrimary otherwise. Bolt prefix  only when on AC,
    // visible without violating the icon-salad rule because it sits
    // *outside* the battery glyph and reads as the "plugged" affordance.
    WingPill {
        id: batteryPill
        Layout.alignment: Qt.AlignVCenter
        onClicked: Ui.togglePopover("battery")

        readonly property real pct: UPower.displayDevice.isPresent
            ? UPower.displayDevice.percentage : 0
        readonly property bool charging:
            UPower.displayDevice.state === UPowerDeviceState.Charging
        readonly property bool low: !charging && pct < 0.15
        readonly property string batteryGlyph:
            pct >= 0.95 ? ""  // nf-fa-battery_full
          : pct >= 0.70 ? ""  // nf-fa-battery_three_quarters
          : pct >= 0.45 ? ""  // nf-fa-battery_half
          : pct >= 0.20 ? ""  // nf-fa-battery_quarter
                        : ""  // nf-fa-battery_empty

        Text {
            Layout.alignment: Qt.AlignVCenter
            visible: batteryPill.charging
            text: ""  // nf-fa-bolt
            color: Colors.success
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
            Behavior on color { CAnim { type: "standard" } }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: batteryPill.batteryGlyph
            color: batteryPill.low      ? Colors.critical
                 : batteryPill.charging ? Colors.success
                                        : root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            Behavior on color { CAnim { type: "standard" } }
        }
        Text {
            Layout.alignment: Qt.AlignVCenter
            text: UPower.displayDevice.isPresent
                  ? Math.round(UPower.displayDevice.percentage * 100)
                  : "—"
            color: root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
            font.features: ({ "tnum": 1 })
            Behavior on color { CAnim { type: "standard" } }
        }
    }

    // Keep the default-sink audio properties alive so the volume binding
    // doesn't flap when the default sink changes.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
}
