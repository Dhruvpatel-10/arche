import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../theme"

// BarLeftWing — split-notch left panel. Hugs the top-left corner and
// rounds only its bottom-right corner, forming the left half of the
// notch. Content: Arch glyph + numbered workspace tiles.
//
// The active-window chip used to live here too but was removed per the
// user's feedback (2026-04-20) — the chip added chrome without a job the
// rest of the UI doesn't already tell you. The left wing is now pure
// workspace navigation.
//
// Workspace count is dynamic:
//   • base            = clamp( floor(screen.width / 384), 5, 10 )
//   • highestRelevant = max( highest occupied, focused workspace id )
//   • final           = min( 10, max(base, highestRelevant) )
//
// So a 1080p screen shows 5, a 2.5K shows 6–7, a 4K shows 10. If the
// user opens a window on workspace 8, the wing grows to include 8.
// If the user *navigates* to workspace 7 (even empty), the wing grows
// to 7 — otherwise the active tile would have nowhere to land and the
// user's current workspace would be invisible. When they leave that
// empty workspace, the wing smoothly shrinks back to base.
PanelWindow {
    id: root
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "arche-bar-left"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; left: true }
    color: "transparent"
    exclusiveZone: Sizing.pxFor(30, _sn)
    implicitWidth: wingBody.width
    implicitHeight: Sizing.pxFor(30, _sn)

    // Convenience alias so every pxFor call stays concise.
    readonly property string _sn: root.screen?.name ?? ""

    // ─── Adaptive surface state ───────────────────────────────────────
    // Look up the monitor that owns this wing by screen name. Using the
    // screen name (not Hyprland.focusedMonitor) ensures per-monitor
    // independence — two monitors, two independent fullscreen states.
    readonly property var _mon: {
        const ms = Hyprland.monitors?.values ?? []
        const n  = root.screen?.name ?? ""
        return ms.find(m => m.name === n) ?? null
    }
    readonly property bool hasFullscreen:
        !!(_mon && _mon.activeWorkspace && _mon.activeWorkspace.hasFullscreen)

    // Single numeric driver: 0 = translucent (default/resting),
    // 1 = opaque (fullscreen app under the wing).
    // Defaults to 0 so startup never flashes opaque.
    property real opacityScale: hasFullscreen ? 1 : 0
    Behavior on opacityScale { Anim { type: "adaptive" } }

    // ─── Dynamic workspace count ──────────────────────────────────────
    // Math — not magic. Every 384 logical px of screen width buys one
    // tile, clamped to the design's sweet spot [5, 10]. Then we bump up
    // to cover any workspace the user has actually opened.
    readonly property int _baseCount: {
        const w = root.screen ? root.screen.width : 1920
        return Math.max(5, Math.min(10, Math.floor(w / 384)))
    }
    readonly property int _highestRelevant: {
        let hi = 0
        const vals = Hyprland.workspaces.values ?? []
        for (let i = 0; i < vals.length; i++) {
            const w = vals[i]
            const c = w?.toplevels?.values?.length ?? 0
            if (c > 0 && w.id > hi && w.id <= 10) hi = w.id
        }
        // Include the currently-focused workspace. User may be sitting
        // on a higher, empty workspace — we still need to show its tile
        // so the active marker has somewhere to land.
        const active = Hyprland.focusedWorkspace?.id ?? 0
        if (active > hi && active <= 10) hi = active
        return hi
    }
    readonly property int wsCount: Math.min(10, Math.max(_baseCount, _highestRelevant))

    Rectangle {
        id: wingBody
        anchors.top: parent.top
        anchors.left: parent.left
        height: Sizing.pxFor(30, _sn)
        width: row.implicitWidth + Spacing.lg + Spacing.md
        color: "transparent"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Sizing.pxFor(14, _sn)
        border.color: Colors.border
        border.width: Shape.borderThin

        // Adaptive surface: two stacked Rectangles with complementary
        // opacities driven by the single opacityScale driver. No
        // separate Behavior on each opacity — that is trap #9.
        // Radii mirror wingBody's corner contract exactly so the
        // silhouette never wavers between opacity states (trap #1).
        Rectangle {
            id: translucentLayer
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
            id: opaqueLayer
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Colors.surfaceOpaque
            opacity: root.opacityScale
            z: 0
        }

        // Width change when wsCount shifts — keep it smooth so the notch
        // doesn't snap when a new workspace gets used.
        Behavior on width { Anim { type: "standard" } }

        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Spacing.lg
            spacing: Spacing.md
            z: 1

            // ─── Arch logo ───────────────────────────────────────────
            Item {
                Layout.preferredWidth: Sizing.pxFor(16, _sn)
                Layout.preferredHeight: Sizing.pxFor(16, _sn)
                Layout.alignment: Qt.AlignVCenter
                Text {
                    anchors.centerIn: parent
                    text: "\uf303"   // nf-dev-archlinux
                    color: Colors.accentAlt
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                }
            }

            // ─── Workspace tiles ─────────────────────────────────────
            Row {
                id: wsRow
                Layout.alignment: Qt.AlignVCenter
                spacing: Sizing.pxFor(4, _sn)

                // -1 when focusedWorkspace is momentarily null. Falling
                // back to 1 (the old `?? 1`) made workspace 1 flash as
                // "active" every time Hyprland's model flickered during
                // a workspace switch.
                readonly property int activeId:
                    Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
                function wsFor(id) {
                    return Hyprland.workspaces.values.find(w => w.id === id)
                }
                function occupiedCount(id) {
                    return wsFor(id)?.toplevels?.values?.length ?? 0
                }
                function isUrgent(id) {
                    return !!(wsFor(id)?.urgent)
                }

                Repeater {
                    model: root.wsCount
                    delegate: Rectangle {
                        id: wsTile
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool isActive: wsId === wsRow.activeId
                        readonly property int count: wsRow.occupiedCount(wsId)
                        readonly property bool urgent: wsRow.isUrgent(wsId)
                        readonly property bool occupied: count > 0 && !isActive

                        width: Sizing.pxFor(20, _sn)
                        height: Sizing.pxFor(20, _sn)
                        radius: Sizing.pxFor(6, _sn)
                        color: isActive ? Colors.accent
                               : (tileHover.containsMouse ? Colors.tileBg
                                                          : "transparent")
                        // Occupied-but-inactive gets the new workspaceOccupied border.
                        border.color: occupied && !tileHover.containsMouse
                                      ? Colors.workspaceOccupied
                                      : Colors.border
                        border.width: (isActive || tileHover.containsMouse)
                                      ? 0 : Shape.borderThin

                        Behavior on color { CAnim { type: "fast" } }

                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: wsTile.wsId
                            color: wsTile.isActive
                                   ? Colors.bgAlt
                                   : (wsTile.count > 0 ? Colors.fg
                                      : (wsTile.urgent ? Colors.critical
                                                        : Colors.fgDim))
                            font.family: Typography.fontMono
                            // Active tile: fontCaption + DemiBold for the "chiselled" feel.
                            // Occupied: fontCaption + Medium. Empty: fontCaption + Normal.
                            font.pixelSize: Typography.fontCaption
                            font.weight: wsTile.isActive
                                         ? Typography.weightDemiBold
                                         : (wsTile.count > 0
                                            ? Typography.weightMedium
                                            : Typography.weightNormal)

                            // Urgent: drive a separate `pulseVal` and bind
                            // opacity through a conditional — when urgent
                            // flips off the animation stops, pulseVal stays
                            // wherever it landed, but opacity snaps back to
                            // 1 via the conditional instead of freezing
                            // mid-dim. Animating opacity directly (the old
                            // `SequentialAnimation on opacity`) leaves the
                            // text permanently dimmed.
                            property real pulseVal: 1
                            opacity: (wsTile.urgent && !wsTile.isActive)
                                     ? pulseVal : 1

                            SequentialAnimation {
                                running: wsTile.urgent && !wsTile.isActive
                                loops: Animation.Infinite
                                NumberAnimation {
                                    target: wsText; property: "pulseVal"
                                    from: 1; to: 0.45; duration: 700
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    target: wsText; property: "pulseVal"
                                    from: 0.45; to: 1; duration: 700
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        // Occupancy badge (top-right dot when >1 toplevel)
                        Rectangle {
                            visible: parent.count > 1 && !parent.isActive
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: -Sizing.pxFor(1, _sn)
                            width: Sizing.pxFor(5, _sn); height: Sizing.pxFor(5, _sn)
                            radius: width / 2
                            color: Colors.accent
                        }

                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            anchors.margins: -Sizing.pxFor(3, _sn)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                        }
                    }
                }
            }
        }
    }
}
