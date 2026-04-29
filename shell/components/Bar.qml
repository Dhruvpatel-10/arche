import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../services"
import "../theme"

// Bar — unified full-width top bar. One PanelWindow per screen (via the
// Variants in shell.qml). macOS-style: edge-to-edge, flat bottom, no
// corner radii. Replaces the previous three-wing design (BarLeftWing +
// BarCenterWing + BarRightWing + BarExclusionZone) with a single layer
// surface. See D029 — the shell is one flat top strip, period.
//
// ─── Composition ─────────────────────────────────────────────────────
// Content lives in three independently-anchored cluster children of the
// surface rectangle:
//
//   left   (verticalCenter + left)            — BarWorkspaces + NowPlayingStrip
//   center (verticalCenter + horizontalCenter) — BarClock
//   right  (verticalCenter + right)            — BarStatusPills
//
// Anchoring (not RowLayout) keeps the clock TRULY centered regardless of
// side-cluster width — workspace count and now-playing title length
// never shift the time off-center.
//
// ─── Adaptive surface (wallpaper-aware) ──────────────────────────────
// Two stacked Rectangles with complementary opacities crossfade via one
// numeric driver (`opacityScale`). Pitfall #9: one driver, multiple
// Behaviors, never two racing.
//
//   opacityScale = 0   → translucent layer visible (default resting)
//   opacityScale = 1   → opaque layer visible (fullscreen under the bar)
//
// The TRANSLUCENT layer's color tracks wallpaper luminance via the
// WallpaperContrast service:
//   dark wallpaper   → Colors.surfaceTranslucent       (bgSurface @78%)
//   light wallpaper  → Colors.surfaceTranslucentLight  (warm off-white @78%)
// Same 78% alpha in both variants so the crossfade envelope is identical
// — only the hue shifts.
//
// The OPAQUE layer always reverts to Colors.surfaceOpaque (dark) — a
// fullscreen app gets a solid ground regardless of wallpaper. We don't
// chameleon under fullscreen.
//
// Foreground colors (text, icons) flip per-cluster through the same
// WallpaperContrast.isLight + hasFullscreen selector. See the
// BarWorkspaces / BarClock / BarStatusPills sources for the token split.
//
// ─── Exclusion zone ──────────────────────────────────────────────────
// The bar owns its exclusive zone directly — no separate exclusion
// layer needed (the old BarExclusionZone existed only because the three
// corner-anchored wings each reserved only their own footprint, leaving
// the center of the top edge unreserved). A full-width PanelWindow with
// `ExclusionMode.Auto` reserves the whole strip cleanly.
//
// ─── Namespace ───────────────────────────────────────────────────────
// "arche-bar" — construction-only string literal (pitfall #6). Hyprland
// layerrules matching `namespace:arche-bar` target this bar; rules that
// targeted the old `arche-bar-{left,center,right,exclusion}` namespaces
// must be migrated to `arche-bar`.
PanelWindow {
    id: root
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "arche-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Auto

    anchors { top: true; left: true; right: true }
    color: "transparent"

    readonly property string _sn: root.screen?.name ?? ""
    implicitHeight: Sizing.barHeightFor(_sn)
    exclusiveZone: Sizing.barHeightFor(_sn)

    // ─── Adaptive surface state ───────────────────────────────────────
    // Resolve THIS bar's own monitor by screen name so two monitors get
    // independent fullscreen state — using Hyprland.focusedMonitor would
    // flip both bars' surfaces in lockstep.
    readonly property var _mon: {
        const ms = Hyprland.monitors?.values ?? []
        const n  = root.screen?.name ?? ""
        return ms.find(m => m.name === n) ?? null
    }
    readonly property bool hasFullscreen:
        !!(_mon && _mon.activeWorkspace && _mon.activeWorkspace.hasFullscreen)

    // Single numeric driver — 0 = translucent (resting), 1 = opaque.
    // Defaults to 0 so startup never flashes opaque.
    property real opacityScale: hasFullscreen ? 1 : 0
    Behavior on opacityScale { Anim { type: "adaptive" } }

    // ─── Surface layers ──────────────────────────────────────────────
    // Translucent layer — color tracks wallpaper luminance. The Behavior
    // on color smooths the light↔dark swap whenever the user switches
    // to a wallpaper on the other side of the luminance threshold.
    Rectangle {
        id: translucentLayer
        anchors.fill: parent
        color: WallpaperContrast.isLight
               ? Colors.surfaceTranslucentLight
               : Colors.surfaceTranslucent
        opacity: 1 - root.opacityScale
        Behavior on color { CAnim { type: "standard" } }
        z: 0
    }
    // Opaque layer — constant dark ground for the fullscreen case.
    Rectangle {
        id: opaqueLayer
        anchors.fill: parent
        color: Colors.surfaceOpaque
        opacity: root.opacityScale
        z: 0
    }

    // ─── Left cluster: workspaces + now-playing strip ────────────────
    Row {
        id: leftCluster
        anchors.left: parent.left
        anchors.leftMargin: Spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        spacing: Spacing.md
        z: 1

        BarWorkspaces {
            anchors.verticalCenter: parent.verticalCenter
            screenName: root._sn
            hasFullscreen: root.hasFullscreen
            screenWidth: root.screen ? root.screen.width : 1920
        }

        NowPlayingStrip {
            anchors.verticalCenter: parent.verticalCenter
            screenName: root._sn
            hasFullscreen: root.hasFullscreen
        }
    }

    // ─── Center cluster: clock + date ────────────────────────────────
    BarClock {
        id: centerCluster
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        screenName: root._sn
        hasFullscreen: root.hasFullscreen
        z: 1
    }

    // ─── Right cluster: recording + status pills ─────────────────────
    BarStatusPills {
        id: rightCluster
        anchors.right: parent.right
        anchors.rightMargin: Spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        screenName: root._sn
        hasFullscreen: root.hasFullscreen
        z: 1
    }
}
