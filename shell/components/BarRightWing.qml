import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."
import "../services"
import "../theme"

// BarRightWing — split-notch right panel. Hugs the top-right corner,
// rounds only its bottom-left corner. Status pills: recording (when
// active), notifications, wifi, bluetooth, volume, battery. Clicks on
// the right-side pills still drive the existing drawers (calendar,
// control center, powermenu) so none of the wider panel UX regresses.
PanelWindow {
    id: root
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "arche-bar-right"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; right: true }
    color: "transparent"
    // BarLeftWing owns the exclusiveZone reservation for the whole notch
    // row; right wing just paints inside it. See BarLeftWing.qml.
    exclusiveZone: 0
    implicitWidth: wingBody.width
    implicitHeight: Sizing.pxFor(30, _sn)

    // Convenience alias so every pxFor call stays concise.
    readonly property string _sn: root.screen?.name ?? ""

    // ─── Adaptive surface state ───────────────────────────────────────
    readonly property var _mon: {
        const ms = Hyprland.monitors?.values ?? []
        const n  = root.screen?.name ?? ""
        return ms.find(m => m.name === n) ?? null
    }
    readonly property bool hasFullscreen:
        !!(_mon && _mon.activeWorkspace && _mon.activeWorkspace.hasFullscreen)

    // Single numeric driver: 0 = translucent, 1 = opaque.
    property real opacityScale: hasFullscreen ? 1 : 0
    Behavior on opacityScale { Anim { type: "adaptive" } }

    Rectangle {
        id: wingBody
        anchors.top: parent.top
        anchors.right: parent.right
        height: Sizing.pxFor(30, _sn)
        width: row.implicitWidth + Spacing.lg + Spacing.md
        color: "transparent"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Sizing.pxFor(14, _sn)
        bottomRightRadius: 0
        border.color: Colors.border
        border.width: Shape.borderThin

        // Adaptive surface layers — same one-driver, two-rect pattern as
        // BarLeftWing. Radii mirror wingBody so silhouette is stable
        // across the crossfade (trap #1 / trap #9).
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Colors.surfaceTranslucent
            opacity: 1 - root.opacityScale
            z: 0
        }
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Colors.surfaceOpaque
            opacity: root.opacityScale
            z: 0
        }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Spacing.lg
            spacing: Sizing.pxFor(7, _sn)
            z: 1

            // ─── Recording pill (conditional) ────────────────────────
            WingPill {
                Layout.alignment: Qt.AlignVCenter
                visible: Ui.recording
                Rectangle {
                    Layout.preferredWidth: Sizing.pxFor(6, _sn)
                    Layout.preferredHeight: Sizing.pxFor(6, _sn)
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

            // ─── Notifications pill ──────────────────────────────────
            WingPill {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Ui.togglePopover("notifs")
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: "\uf0f3"   // bell
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: (Notifs.history?.length ?? 0)
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.features: ({ "tnum": 1 })
                }
            }

            // ─── Separator: deliberate 1.5×14 rule ───────────────────
            // Was 1×12 at 60% opacity — effectively a ghost at 1.5×
            // scale. Now uses Colors.separator + Effects.opacitySubtle
            // for a visible tick between notification and status pills.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Sizing.pxFor(1.5, _sn)
                Layout.preferredHeight: Sizing.pxFor(14, _sn)
                color: Colors.separator
                opacity: Effects.opacitySubtle
            }

            // ─── Wifi pill (dot reflects radio state) ─────────────────
            WingPill {
                Layout.alignment: Qt.AlignVCenter
                statusOn: Net.radioOn
                onClicked: Ui.togglePopover("net")
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Net.connected ? "\uf1eb" : "\uf6ac"
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
            }

            // ─── Bluetooth pill ──────────────────────────────────────
            WingPill {
                Layout.alignment: Qt.AlignVCenter
                statusOn: Bt.powered
                onClicked: Ui.togglePopover("bt")
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Bt.connected ? "\uf293" : "\uf294"
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
            }

            // ─── Volume pill ─────────────────────────────────────────
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
                    text: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                          ? "\uf6a9" : "\uf028"
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.features: ({ "tnum": 1 })
                }
            }

            // ─── Separator: before battery ────────────────────────────
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Sizing.pxFor(1.5, _sn)
                Layout.preferredHeight: Sizing.pxFor(14, _sn)
                color: Colors.separator
                opacity: Effects.opacitySubtle
            }

            // ─── Battery pill ────────────────────────────────────────
            WingPill {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Ui.togglePopover("battery")

                // Battery glyph — small rounded rect with interior fill bar.
                // Body: 20×10 (up from 18×9) for a crisper fill at 1.5×.
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Sizing.pxFor(20, _sn)
                    Layout.preferredHeight: Sizing.pxFor(10, _sn)
                    radius: Sizing.pxFor(2, _sn)
                    color: "transparent"
                    border.color: Colors.fgMuted
                    border.width: Shape.borderThin
                    readonly property real pct: UPower.displayDevice.isPresent
                        ? UPower.displayDevice.percentage : 0
                    readonly property bool charging:
                        UPower.displayDevice.state === UPowerDeviceState.Charging
                    readonly property bool low: !charging && pct < 0.15

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: Sizing.pxFor(1, _sn)
                        width: Math.max(0, (parent.width - Sizing.pxFor(2, _sn))
                                        * parent.pct)
                        radius: Sizing.pxFor(1, _sn)
                        color: parent.low      ? Colors.critical
                             : parent.charging ? Colors.success
                                               : Colors.fg
                        Behavior on width { Anim { type: "fast" } }
                        Behavior on color { CAnim { type: "standard" } }
                    }
                    // Nub on the right edge
                    Rectangle {
                        anchors.left: parent.right
                        anchors.leftMargin: Sizing.pxFor(1, _sn)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Sizing.pxFor(1.5, _sn)
                        height: Sizing.pxFor(3, _sn)
                        radius: Sizing.pxFor(1, _sn)
                        color: Colors.fgMuted
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: UPower.displayDevice.isPresent
                          ? Math.round(UPower.displayDevice.percentage * 100)
                          : "—"
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
}
