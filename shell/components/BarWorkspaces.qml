import QtQuick
import Quickshell.Hyprland
import "../services"
import "../theme"

// BarWorkspaces — workspace numerals row. Factored out of the old
// BarLeftWing so Bar.qml stays readable. Unboxed look — each workspace
// is a numeral + one of three status marks:
//
//   active   → 2px amber underline, numeral in fgPrimary demibold
//   occupied → numeral in fgPrimary medium, no mark
//   empty    → numeral in fgDim, no mark
//
// Urgent workspaces pulse the numeral's opacity. The active underline
// tracks position via the parent Row's implicit layout — no explicit
// Behavior needed.
//
// ─── Dynamic count ────────────────────────────────────────────────────
//
//   base            = clamp( floor(screenWidth / 384), 5, 10 )
//   highestRelevant = max( highest occupied workspace id, focused id )
//   final           = min( 10, max(base, highestRelevant) )
//
// 1080p → 5 tiles; 2.5K → 6–7; 4K → 10. Navigating to a higher empty
// workspace grows the row so the active marker has a tile to land on.
// When the user leaves it, the row shrinks back to base — parent Row's
// width animation carries the silhouette.
//
// ─── Adaptive foreground ──────────────────────────────────────────────
// `fgPrimary` / `fgDim` flip to the dark-on-light palette when the
// wallpaper is light AND the bar is translucent (i.e. no fullscreen
// window is blacking out the bar's surface). Under fullscreen we revert
// to the warm-white tokens — the opaque dark surface always wins.
Row {
    id: root

    // ─── Inputs ───────────────────────────────────────────────────────
    property string screenName: ""
    property bool hasFullscreen: false
    // Pre-scale logical width of the screen. Supplied by Bar.qml from
    // its own `screen.width` (we can't reach the QML `screen` from here
    // without threading the whole ShellScreen reference).
    property int screenWidth: 1920

    // ─── Adaptive foreground selector ─────────────────────────────────
    readonly property bool _useLight: !hasFullscreen && WallpaperContrast.isLight
    readonly property color fgPrimary: _useLight ? Colors.fgOnLight : Colors.fg
    readonly property color fgDim:     _useLight ? Colors.fgDimOnLight : Colors.fgDim

    spacing: Sizing.pxFor(6, screenName)

    // ─── Workspace derivations ────────────────────────────────────────
    // -1 when focusedWorkspace is momentarily null. Falling back to 1
    // made workspace 1 flash "active" every time Hyprland's model
    // flickered during a workspace switch. See old BarLeftWing.
    readonly property int activeId:
        Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

    function _wsFor(id) {
        return Hyprland.workspaces.values.find(w => w.id === id)
    }
    function _occupiedCount(id) {
        return _wsFor(id)?.toplevels?.values?.length ?? 0
    }
    function _isUrgent(id) {
        return !!(_wsFor(id)?.urgent)
    }

    readonly property int _baseCount:
        Math.max(5, Math.min(10, Math.floor(screenWidth / 384)))

    readonly property int _highestRelevant: {
        let hi = 0
        const vals = Hyprland.workspaces.values ?? []
        for (let i = 0; i < vals.length; i++) {
            const w = vals[i]
            const c = w?.toplevels?.values?.length ?? 0
            if (c > 0 && w.id > hi && w.id <= 10) hi = w.id
        }
        const active = Hyprland.focusedWorkspace?.id ?? 0
        if (active > hi && active <= 10) hi = active
        return hi
    }

    readonly property int wsCount:
        Math.min(10, Math.max(_baseCount, _highestRelevant))

    // ─── Numerals ─────────────────────────────────────────────────────
    Repeater {
        model: root.wsCount
        delegate: Item {
            id: wsMarker
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: wsId === root.activeId
            readonly property int count: root._occupiedCount(wsId)
            readonly property bool urgent: root._isUrgent(wsId)
            readonly property bool occupied: count > 0 && !isActive

            width: Sizing.pxFor(16, root.screenName)
            height: Sizing.pxFor(20, root.screenName)

            // Numeral — color + weight convey state, underline conveys
            // "which one am I on right now". No dot above; the old amber
            // bullet was redundant chrome.
            Text {
                id: wsText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: wsMarker.wsId
                color: wsMarker.isActive
                       ? root.fgPrimary
                       : (wsMarker.urgent ? Colors.critical
                          : (wsMarker.occupied ? root.fgPrimary
                                               : root.fgDim))
                font.family: Typography.fontMono
                font.pixelSize: Typography.fontCaption
                font.weight: wsMarker.isActive
                             ? Typography.weightDemiBold
                             : (wsMarker.occupied
                                ? Typography.weightMedium
                                : Typography.weightNormal)
                font.features: ({ "tnum": 1 })
                Behavior on color { CAnim { type: "standard" } }

                // Hover nudge — confirms the marker is clickable.
                opacity: tileHover.containsMouse ? 0.75 : 1.0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                // Urgent pulse — driven via its own property so stopping
                // the animation doesn't freeze visible opacity mid-cycle.
                property real pulseVal: 1
                SequentialAnimation {
                    running: wsMarker.urgent && !wsMarker.isActive
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

            // Active underline — 2px amber, slides between workspaces
            // via its parent Row's layout animation.
            Rectangle {
                visible: wsMarker.isActive
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Sizing.pxFor(2, root.screenName)
                anchors.horizontalCenter: parent.horizontalCenter
                width: Sizing.pxFor(12, root.screenName)
                height: Sizing.pxFor(2, root.screenName)
                radius: height / 2
                color: Colors.accent
            }

            MouseArea {
                id: tileHover
                anchors.fill: parent
                anchors.margins: -Sizing.pxFor(3, root.screenName)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + wsMarker.wsId)
            }
        }
    }
}
