import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../osd"
import "../theme"

// OsdOverlay — the on-screen pill. Reads `Osd.payload` and renders; knows
// nothing about volume vs brightness vs caps lock. Providers fill in the
// payload; this component decides layout and variant colors.
//
// One surface per screen via Variants so the pill only appears on the
// focused output.
StyledWindow {
    id: root
    name: "osd"

    property var modelData
    screen: modelData

    visible: Osd.active
             && Hyprland.focusedMonitor
             && Hyprland.focusedMonitor.name === modelData.name

    anchors { bottom: true; left: true; right: true }
    implicitHeight: Sizing.px(160)
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ─── Derived from payload ──────────────────────────────────────────
    readonly property var  p:       Osd.payload
    readonly property bool hasBar:  p && typeof p.percent === "number" && p.percent >= 0
    readonly property bool alert:   p && (p.variant === "muted" || p.variant === "warn")
    readonly property color fill:   alert ? Colors.critical : Colors.accent
    readonly property color discBg: alert ? Colors.critical : Colors.bgAlt
    readonly property color discFg: alert ? Colors.bgAlt    : Colors.fg

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sizing.px(60)
        width:  Sizing.px(340)
        height: Sizing.px(68)
        color: Colors.card
        radius: Shape.radiusLg
        border.color: Colors.border
        border.width: Shape.borderThin

        opacity: Osd.active ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Motion.durationMed; easing.type: Motion.easeOut }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin:  Spacing.lg
            anchors.rightMargin: Spacing.lg
            spacing: Spacing.md

            // Icon disc
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth:  Sizing.px(48)
                Layout.preferredHeight: Sizing.px(48)
                radius: width / 2
                color: root.discBg
                Text {
                    anchors.centerIn: parent
                    text: root.p ? root.p.icon : ""
                    color: root.discFg
                    font {
                        family:    Typography.fontMono
                        pixelSize: Typography.fontTitle
                    }
                }
            }

            // Track + fill (only when payload has a percent)
            Rectangle {
                visible: root.hasBar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Sizing.px(6)
                radius: height / 2
                color: Colors.bgAlt

                Rectangle {
                    width:  parent.width * Math.max(0, Math.min(100, root.hasBar ? root.p.percent : 0)) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.fill
                    Behavior on width {
                        NumberAnimation {
                            duration: Motion.durationFast
                            easing.type: Motion.easeOut
                        }
                    }
                }
            }

            // Label-only filler: when there's no bar we still want the
            // label flush-right, so stretch an empty item.
            Item {
                visible: !root.hasBar
                Layout.fillWidth: true
                Layout.preferredHeight: 1
            }

            // Right readout: label wins, else "nn%"
            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Sizing.px(72)
                horizontalAlignment: Text.AlignRight
                text: {
                    if (!root.p) return ""
                    if (root.p.label && root.p.label.length > 0) return root.p.label
                    if (root.hasBar) return root.p.percent + "%"
                    return ""
                }
                color: Colors.fg
                font {
                    family:    Typography.fontSans
                    pixelSize: Typography.fontLabel
                    weight:    Typography.weightDemiBold
                    features:  { "tnum": 1 }
                }
                elide: Text.ElideRight
            }
        }
    }
}
