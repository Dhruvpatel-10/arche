import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import ".."
import "../theme"
import "../services"

// IslandWindow — the living notch. One per screen. The island is a void
// cut into the top edge; content moves, the void never colors.
//
// THREE TIERS OF DISCLOSURE (beats Apple's two):
//
//   compact  — default, width-led summary (300 × 30 for playing)
//   peek     — hover 180 ms, grows ~15% (348 × 40), +time remaining,
//              +1.5 px accent scrubber line at the bottom edge
//   expanded — click, full media player (380 × 340)
//
// SPATIAL CONTINUITY: the 1.5 px peek scrubber and the 4 px expanded
// scrubber share the same binding + accent identity. The eye tracks a
// single bar growing, not two UIs swapping. Framer's `layoutId` spirit
// in QML.
//
// SCROLL IS A FIRST-CLASS VERB (Apple can't do this on iOS):
//
//   over playing    seek ±5 s
//   over volume     volume ±5 %
//   over idle       brightness ±5 %  (via services/Brightness)
//   over focus      timer ±1 min
//
// DESIGN RULES (docs/island-design.md):
//   1. Chrome is flat islandInk always; never swaps on hover.
//   2. Void illusion — clip: true + rounded bottom only.
//   3. Width leads height on expand; height leads width on collapse.
//   4. Content scales-in 0.94→1.0 AND cross-fades on state entry.
//   5. Pointer affordance only when there's something to expand into.
//
// DUAL-MONITOR READY: all sizes go through Sizing.px / Sizing.fpx so
// 16" 2.8K @ 1.6× and 27" 4K @ 1.5× render at the same logical footprint
// but proportionally to their physical density.
PanelWindow {
    id: root
    property var modelData
    screen: modelData

    WlrLayershell.namespace: "arche-island"
    WlrLayershell.layer: WlrLayer.Top
    // OnDemand while expanded — Exclusive looks tempting (guaranteed
    // focus) but on Hyprland it fights `HyprlandFocusGrab`: the grab's
    // activate→cleared cycle races the exclusive focus claim and the
    // island collapses the instant it opens. OnDemand matches caelestia's
    // drawer pattern: the window is eligible to receive keyboard input
    // while active, and the `forceActiveFocus()` below plus the click
    // that opened the drawer route Qt's internal focus to the
    // FocusScope. Outside clicks still clear the grab → collapse.
    WlrLayershell.keyboardFocus: Ui.expanded
                                 ? WlrKeyboardFocus.OnDemand
                                 : WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0
    implicitHeight: Sizing.px(360)

    // ─── State → dimension table ──────────────────────────────────────
    readonly property string state: Ui.islandState

    // True while the user hovers the playing state past the dwell
    // threshold. Drives the peek tier: +48 px width, +10 px height,
    // reveals bottom scrubber + time-remaining text.
    property bool peekActive: false

    readonly property int idleH:     Sizing.px(30)
    readonly property int peekH:     Sizing.px(40)
    readonly property int expandedH: Sizing.px(340)

    readonly property int targetW: {
        if (state === "expanded") return Sizing.px(380)
        if (peekActive && state === "playing") return Sizing.px(348)
        switch (state) {
            case "playing":   return Sizing.px(300)
            case "volume":    return Sizing.px(240)
            case "toast":     return Sizing.px(320)
            case "recording": return Sizing.px(200)
            case "focus":     return Sizing.px(240)
            case "idle":
            default:          return Sizing.px(220)
        }
    }
    readonly property int targetH: {
        if (state === "expanded") return expandedH
        if (peekActive && state === "playing") return peekH
        return idleH
    }

    // Click-through outside the island rect. When the source menu is
    // open, combine the island region with the menu's geometry so clicks
    // hit the menu card instead of falling through. When closed, the
    // menu's geometry collapses to zero so the area below the notch
    // stays click-through.
    mask: Region {
        item: island
        Region {
            x: sourceMenu.x
            y: sourceMenu.y
            width:  root.sourceMenuOpen ? sourceMenu.width  : 0
            height: root.sourceMenuOpen ? sourceMenu.height : 0
        }
    }

    // ─── Peek dwell timer ─────────────────────────────────────────────
    Timer {
        id: peekTimer
        interval: 180
        repeat: false
        onTriggered: root.peekActive = true
    }

    // ─── The island surface ───────────────────────────────────────────
    Rectangle {
        id: island
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.targetW
        height: root.targetH

        color: Colors.islandInk

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Math.min(Sizing.px(14), height / 2)
        bottomRightRadius: Math.min(Sizing.px(14), height / 2)
        border.width: 0
        clip: true

        // ─── Breath signature ─────────────────────────────────────────
        // Imperceptible-on-purpose scale oscillation (1.000 → 1.004) at
        // ~4 s period while a player is actively playing in compact
        // (non-peek, non-expanded). Transform origin at Top so the cut-
        // out-of-the-screen illusion stays fixed — the island "breathes
        // downward", never pushing past the top edge. Sub-pixel motion
        // on most screens; you feel it more than see it.
        //
        // Driver split: `breathPulse` does the animating, `scale` is a
        // conditional binding. When breathing turns off (state change,
        // peek, pause), scale snaps back to 1.0 via Behavior — no
        // sub-pixel deformation leaks into expanded/peek states.
        transformOrigin: Item.Top
        readonly property bool _breathing: root.state === "playing"
                                           && (root._player?.isPlaying ?? false)
                                           && !root.peekActive
        property real breathPulse: 1.0
        scale: _breathing ? breathPulse : 1.0
        Behavior on scale {
            enabled: !island._breathing
            NumberAnimation { duration: 200; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on breathPulse {
            running: island._breathing
            loops: Animation.Infinite
            NumberAnimation {
                from: 1.000; to: 1.004
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.004; to: 1.000
                duration: 2000
                easing.type: Easing.InOutSine
            }
        }

        // Width leads on expand, height leads on collapse — prevents
        // the squashed-rectangle frame mid-morph.
        Behavior on width {
            SequentialAnimation {
                PauseAnimation { duration: root.state === "expanded" ? 0 : 60 }
                NumberAnimation {
                    duration: Motion.durationMed
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.emphasized
                }
            }
        }
        Behavior on height {
            SequentialAnimation {
                PauseAnimation { duration: root.state === "expanded" ? 60 : 0 }
                NumberAnimation {
                    duration: Motion.durationMed
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.emphasized
                }
            }
        }

        // ─── Ambient art fill (expanded only) ─────────────────────────
        // Low-opacity stretched album art as chromatic backdrop. The
        // expanded content reads over it with full contrast because the
        // effective brightness stays below ~20% even with light art.
        // This is the "beat Apple" move — their island is always ink
        // black; ours hints at the music's color identity when opened.
        Item {
            id: ambientArt
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: (root.state === "expanded"
                      && Ui.expandedView === "media"
                      && root._player?.trackArtUrl) ? 0.18 : 0
            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.InOutSine }
            }
            Image {
                anchors.fill: parent
                source: root._player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: status === Image.Ready
            }
            // Bottom-to-top subtle vignette so the transport row (bottom
            // of expanded) never sits on a bright art patch.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Colors.islandInk }
                }
                opacity: 0.35
            }
        }

        // ─── IDLE ─────────────────────────────────────────────────────
        Item {
            id: idleContainer
            anchors.fill: parent
            property real stateIn: root.state === "idle" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Spacing.sm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(clockTick.time, "HH:mm")
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightDemiBold
                    font.features: ({ "tnum": 1 })
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Sizing.px(2); height: Sizing.px(2)
                    radius: width / 2
                    color: Colors.fgDim
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(clockTick.time, "ddd · MMM d")
                    color: Colors.fgMuted
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                }
            }

            // Idle click → open system panel (no player needed); scroll
            // still adjusts brightness. The cursor affordance is safe
            // because expanded is ALWAYS available now — the system view
            // is the fallback content when no Mpris player is live.
            MouseArea {
                anchors.fill: parent
                enabled: root.state === "idle"
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.tryExpand()
                onWheel: ev => {
                    const delta = ev.angleDelta.y > 0 ? 5 : -5
                    Brightness.set(Brightness.percent + delta)
                    ev.accepted = true
                }
            }
        }

        // ─── PLAYING (compact + peek) ─────────────────────────────────
        Item {
            id: playingContainer
            anchors.fill: parent
            property real stateIn: root.state === "playing" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Spacing.md
                anchors.rightMargin: Spacing.md
                anchors.topMargin: 0
                anchors.bottomMargin: root.peekActive ? Sizing.px(4) : 0
                spacing: Spacing.sm
                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutSine }
                }

                Rectangle {
                    Layout.preferredWidth: Sizing.px(20)
                    Layout.preferredHeight: Sizing.px(20)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Sizing.px(5)
                    color: Colors.bgSurface
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root._player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        visible: !(root._player?.trackArtUrl)
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: Colors.accent }
                            GradientStop { position: 1; color: Colors.critical }
                        }
                    }
                    // Accent halo — 1 px border tinted to the brand accent
                    // at low opacity. Compact tier's hint that this tile
                    // belongs to the living surface, not just a static
                    // thumbnail. Pairs with the expanded ambient art.
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: parent.radius
                        border.color: Colors.accent
                        border.width: Shape.borderThin
                        opacity: 0.28
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: root._player?.trackTitle ?? ""
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightDemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root._player?.trackArtist ?? ""
                        color: Colors.fgMuted
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontMicro
                        elide: Text.ElideRight
                    }
                }

                // Time-remaining (peek only) — cross-fades with EQ bars.
                Text {
                    id: timeRemText
                    Layout.alignment: Qt.AlignVCenter
                    visible: opacity > 0.01
                    opacity: root.peekActive ? 1 : 0
                    text: "-" + root._fmtTime(Math.max(0,
                          (root._player?.length ?? 0) - (root._player?.position ?? 0)))
                    color: Colors.fgMuted
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontMicro
                    font.weight: Typography.weightMedium
                    font.features: ({ "tnum": 1 })
                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.InOutSine }
                    }
                }

                // EQ bars — visible at rest, fade out on peek.
                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Sizing.px(2)
                    visible: opacity > 0.01
                    opacity: root.peekActive ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.InOutSine }
                    }
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: Sizing.px(2)
                            height: Sizing.px(11)
                            radius: 1
                            color: Colors.accent
                            transformOrigin: Item.Bottom
                            SequentialAnimation on scale {
                                running: root.state === "playing"
                                         && (root._player?.isPlaying ?? false)
                                         && !root.peekActive
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 0.35; to: 1.0
                                    duration: 440 + (index * 120) % 360
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 1.0; to: 0.35
                                    duration: 440 + (index * 90) % 380
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }
            }

            // Hover / click / scroll surface.
            MouseArea {
                anchors.fill: parent
                enabled: root.state === "playing"
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root._expandable
                             ? Qt.PointingHandCursor : Qt.ArrowCursor
                onEntered: if (root._expandable) peekTimer.restart()
                onExited: { peekTimer.stop(); root.peekActive = false }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        // Right-click → source menu only meaningful with
                        // more than one live player. Otherwise silent.
                        if (root._multiSource) root.sourceMenuOpen = true
                        return
                    }
                    Ui.tryExpand()
                }
                onWheel: ev => {
                    const p = root._player
                    if (!p || !p.length) return
                    const delta = ev.angleDelta.y > 0 ? 5 : -5
                    const next = Math.max(0, Math.min(p.length, p.position + delta))
                    if (p.canSeek) p.position = next
                    ev.accepted = true
                }
            }
        }

        // ─── VOLUME ───────────────────────────────────────────────────
        Item {
            id: volumeContainer
            anchors.fill: parent
            property real stateIn: root.state === "volume" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Spacing.md
                anchors.rightMargin: Spacing.md
                spacing: Spacing.sm

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                          ? "\uf6a9" : "\uf028"
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(3)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Sizing.px(1.5)
                    color: Colors.bgAlt
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                               * (Pipewire.defaultAudioSink?.audio?.volume ?? 0)
                        radius: parent.radius
                        color: Colors.accent
                        Behavior on width { Anim { type: "fast" } }
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Sizing.px(24)
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
                    color: Colors.fg
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                    font.features: ({ "tnum": 1 })
                }
            }

            // Scroll over volume → volume.
            MouseArea {
                anchors.fill: parent
                enabled: root.state === "volume"
                onWheel: ev => {
                    const s = Pipewire.defaultAudioSink?.audio
                    if (!s) return
                    const step = ev.angleDelta.y > 0 ? 0.05 : -0.05
                    s.volume = Math.max(0, Math.min(1, s.volume + step))
                    Ui.triggerVolume()
                    ev.accepted = true
                }
            }
        }

        // ─── TOAST ────────────────────────────────────────────────────
        Item {
            id: toastContainer
            anchors.fill: parent
            property real stateIn: root.state === "toast" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Spacing.sm
                anchors.rightMargin: Spacing.md
                spacing: Spacing.sm

                Rectangle {
                    Layout.preferredWidth: Sizing.px(20)
                    Layout.preferredHeight: Sizing.px(20)
                    Layout.alignment: Qt.AlignVCenter
                    radius: Sizing.px(6)
                    color: Colors.bgSurface
                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f3"
                        color: Colors.accent
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: Ui.toastData?.summary ?? ""
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightDemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Ui.toastData?.body ?? ""
                        color: Colors.fgMuted
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontMicro
                        elide: Text.ElideRight
                    }
                }
            }

            // Click toast → dismiss early.
            MouseArea {
                anchors.fill: parent
                enabled: root.state === "toast"
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.showToast = false
            }
        }

        // ─── RECORDING ────────────────────────────────────────────────
        Item {
            id: recContainer
            anchors.fill: parent
            property real stateIn: root.state === "recording" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Spacing.sm
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Sizing.px(6); height: Sizing.px(6); radius: width / 2
                    color: Colors.critical
                    SequentialAnimation on opacity {
                        running: root.state === "recording"
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightDemiBold
                    font.letterSpacing: 1.5
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ui.recordingTime ?? "00:00"
                    color: Colors.critical
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        // ─── FOCUS ────────────────────────────────────────────────────
        Item {
            id: focusContainer
            anchors.fill: parent
            property real stateIn: root.state === "focus" ? 1 : 0
            opacity: stateIn
            scale: 0.94 + 0.06 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Spacing.sm
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Sizing.px(14); height: Sizing.px(14); radius: width / 2
                    color: "transparent"
                    border.color: Colors.accentAlt
                    border.width: Shape.borderMd
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Sizing.px(6)
                        height: parent.height - Sizing.px(6)
                        radius: width / 2
                        color: Colors.accentAlt
                        opacity: 0.45
                    }
                    SequentialAnimation on scale {
                        running: root.state === "focus"
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 1.15; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.15; to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Focus"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Ui.focusTime ?? "25:00"
                    color: Colors.accentAlt
                    font.family: Typography.fontMono
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                    font.features: ({ "tnum": 1 })
                }
            }

            // Scroll over focus → adjust timer by ±1 min, clamped [1,99].
            MouseArea {
                anchors.fill: parent
                enabled: root.state === "focus"
                onWheel: ev => {
                    const parts = (Ui.focusTime ?? "25:00").split(":")
                    let m = parseInt(parts[0]) || 25
                    m += ev.angleDelta.y > 0 ? 1 : -1
                    m = Math.max(1, Math.min(99, m))
                    Ui.focusTime = (m < 10 ? "0" : "") + m + ":00"
                    ev.accepted = true
                }
            }
        }

        // ─── EXPANDED: full media player ──────────────────────────────
        ColumnLayout {
            id: mediaView
            anchors.fill: parent
            anchors.margins: Spacing.lg
            spacing: Spacing.md
            property real stateIn: (root.state === "expanded"
                                    && Ui.expandedView === "media") ? 1 : 0
            opacity: stateIn
            scale: 0.96 + 0.04 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            // Header — art + meta
            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.md

                Rectangle {
                    Layout.preferredWidth:  Sizing.px(76)
                    Layout.preferredHeight: Sizing.px(76)
                    radius: Sizing.px(12)
                    color: Colors.bgSurface
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root._player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        visible: !(root._player?.trackArtUrl)
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: Colors.accent }
                            GradientStop { position: 1; color: Colors.critical }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: parent.radius
                        border.color: Colors.accent
                        border.width: Shape.borderThin
                        opacity: 0.18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 2

                    Row {
                        spacing: Sizing.px(6)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(5); height: Sizing.px(5)
                            radius: width / 2
                            color: Colors.accent
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root._player?.isPlaying
                                  ? "NOW PLAYING" : "PAUSED"
                            color: Colors.accent
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightDemiBold
                            font.letterSpacing: 2
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: Spacing.xs
                        text: root._player?.trackTitle ?? "Nothing playing"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontLabel
                        font.weight: Typography.weightDemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root._player?.trackArtist ?? ""
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                        elide: Text.ElideRight
                        opacity: 0.88
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root._player?.trackAlbum ?? ""
                        color: Colors.fgMuted
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontMicro
                        elide: Text.ElideRight
                    }
                }
            }

            // Scrubber (expanded) — the peek bottom line conceptually
            // "grows up" into this. Shared identity: same accent, same
            // binding source (position/length).
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Sizing.px(4)
                Rectangle {
                    id: scrubTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(4)
                    radius: Sizing.px(2)
                    color: Colors.bgAlt
                    Rectangle {
                        id: scrubFill
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius
                        color: Colors.accent
                        width: parent.width * Math.max(0, Math.min(1,
                               ((root._player?.length ?? 0) > 0)
                                   ? ((root._player?.position ?? 0) / root._player.length)
                                   : 0))
                        Behavior on width { Anim { type: "fast" } }
                    }
                    Rectangle {
                        width: Sizing.px(10); height: Sizing.px(10)
                        radius: width / 2
                        color: Colors.accent
                        border.color: Colors.islandInk
                        border.width: Shape.borderMd
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width,
                                                scrubFill.width - width / 2))
                        visible: (root._player?.length ?? 0) > 0
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -Sizing.px(6)
                        anchors.bottomMargin: -Sizing.px(6)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const p = root._player
                            if (!p || !p.length) return
                            const pct = mouse.x / width
                            if (p.canSeek) p.position = pct * p.length
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: root._fmtTime(root._player?.position ?? 0)
                        color: Colors.fgMuted
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        text: "-" + root._fmtTime(Math.max(0,
                              (root._player?.length ?? 0) - (root._player?.position ?? 0)))
                        color: Colors.fgMuted
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            // Transport
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Spacing.md
                IconButton {
                    width: Sizing.px(30); height: Sizing.px(30)
                    radius: width / 2
                    color: "transparent"
                    icon: "\uf074"
                    iconSize: 11
                    iconColor: (root._player?.shuffle ?? false) ? Colors.accent : Colors.fg
                    onClicked: { if (root._player) root._player.shuffle = !root._player.shuffle }
                }
                IconButton {
                    width: Sizing.px(34); height: Sizing.px(34)
                    radius: width / 2
                    color: Colors.bgAlt
                    icon: "\uf048"
                    iconSize: 12
                    onClicked: root._player?.previous()
                }
                IconButton {
                    width: Sizing.px(42); height: Sizing.px(42)
                    radius: Sizing.px(12)
                    color: Colors.accent
                    iconColor: Colors.bgAlt
                    icon: (root._player?.isPlaying ?? false) ? "\uf04c" : "\uf04b"
                    iconSize: 15
                    onClicked: root._player?.togglePlaying()
                }
                IconButton {
                    width: Sizing.px(34); height: Sizing.px(34)
                    radius: width / 2
                    color: Colors.bgAlt
                    icon: "\uf051"
                    iconSize: 12
                    onClicked: root._player?.next()
                }
                IconButton {
                    width: Sizing.px(30); height: Sizing.px(30)
                    radius: width / 2
                    color: "transparent"
                    icon: "\uf01e"
                    iconSize: 11
                    iconColor: (root._player?.loopState ?? 0) > 0 ? Colors.accent : Colors.fg
                    onClicked: {
                        if (!root._player) return
                        const s = root._player.loopState
                        root._player.loopState = (s + 1) % 3
                    }
                }
            }

            // Footer — volume + source
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Spacing.xs
                spacing: Spacing.sm

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(26)
                    radius: Sizing.px(8)
                    color: Colors.bgAlt
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Spacing.sm
                        anchors.rightMargin: Spacing.sm
                        spacing: Spacing.sm
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                                  ? "\uf6a9" : "\uf028"
                            color: Colors.fgMuted
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Sizing.px(3)
                            Layout.alignment: Qt.AlignVCenter
                            radius: Sizing.px(1.5)
                            color: Colors.bgSurface
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width
                                       * (Pipewire.defaultAudioSink?.audio?.volume ?? 0)
                                radius: parent.radius
                                color: Colors.accent
                                Behavior on width { Anim { type: "fast" } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.topMargin: -Sizing.px(6)
                                anchors.bottomMargin: -Sizing.px(6)
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    const s = Pipewire.defaultAudioSink?.audio
                                    if (s) s.volume = Math.max(0, Math.min(1, mouse.x / width))
                                }
                                onWheel: ev => {
                                    const s = Pipewire.defaultAudioSink?.audio
                                    if (!s) return
                                    s.volume = Math.max(0, Math.min(1,
                                        s.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05)))
                                    ev.accepted = true
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
                            color: Colors.fgMuted
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
                Rectangle {
                    Layout.preferredHeight: Sizing.px(22)
                    Layout.preferredWidth: sourceText.implicitWidth + Sizing.px(22)
                    radius: Sizing.px(6)
                    color: Colors.bgAlt
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Spacing.sm
                        anchors.rightMargin: Spacing.sm
                        spacing: Sizing.px(5)
                        Rectangle {
                            Layout.preferredWidth: Sizing.px(5)
                            Layout.preferredHeight: Sizing.px(5)
                            Layout.alignment: Qt.AlignVCenter
                            radius: width / 2
                            color: (root._player?.isPlaying ?? false)
                                   ? Colors.success : Colors.fgMuted
                        }
                        Text {
                            id: sourceText
                            Layout.alignment: Qt.AlignVCenter
                            text: (root._player?.identity ?? "none").toLowerCase()
                            color: Colors.fgMuted
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            font.letterSpacing: 1
                        }
                    }
                }
            }
        }

        // ─── EXPANDED: system panel ───────────────────────────────────
        // The "more things to manage" half of the island. Shown when
        // expandedView === "system": clock + date, CPU/RAM/Disk bars,
        // 2×2 quick-toggles grid, session actions (lock / suspend /
        // power). Mirrors the media layout's cross-fade pattern so
        // flipping between views morphs cleanly.
        //
        // Ref { service: SystemStats } activates the 2-second poll while
        // this view is alive; when collapsed / swapped to media, the Ref
        // is still evaluated (system layout is still instantiated, just
        // transparent) — but that's cheap. The alternative (Loader) would
        // thrash the layout on every toggle. Keep it mounted.
        ColumnLayout {
            id: systemView
            anchors.fill: parent
            anchors.margins: Spacing.lg
            spacing: Spacing.md
            property real stateIn: (root.state === "expanded"
                                    && Ui.expandedView === "system") ? 1 : 0
            opacity: stateIn
            scale: 0.96 + 0.04 * stateIn
            visible: stateIn > 0.01
            Behavior on stateIn {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.standardDecel
                }
            }

            Ref { service: SystemStats }

            // Header — Bricolage-style hero clock, muted date underneath.
            // The big numerals make the system panel feel like a glance
            // surface, not a tool tray.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Spacing.xs
                spacing: 2
                Text {
                    text: Qt.formatTime(clockTick.time, "HH:mm")
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontDisplay
                    font.weight: Typography.weightDemiBold
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    text: Qt.formatDate(clockTick.time, "dddd, MMM d")
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontCaption
                    font.weight: Typography.weightMedium
                }
            }

            // Stats — horizontal rows, label + bar + percent. Mono labels
            // keep visual rhythm with the numeric values on the right.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Sizing.px(5)

                Repeater {
                    model: [
                        { label: "CPU",  pct: SystemStats.cpu },
                        { label: "RAM",  pct: SystemStats.ram },
                        { label: "DISK", pct: SystemStats.disk },
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Spacing.sm
                        Text {
                            Layout.preferredWidth: Sizing.px(34)
                            text: modelData.label
                            color: Colors.fgMuted
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            font.letterSpacing: 1
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Sizing.px(4)
                            Layout.alignment: Qt.AlignVCenter
                            radius: Sizing.px(2)
                            color: Colors.bgAlt
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                width: parent.width
                                       * Math.max(0, Math.min(1, modelData.pct / 100))
                                color: modelData.pct >= 85 ? Colors.critical
                                       : (modelData.pct >= 65 ? Colors.warn
                                                               : Colors.accent)
                                Behavior on width { Anim { type: "fast" } }
                                Behavior on color { CAnim { type: "fast" } }
                            }
                        }
                        Text {
                            Layout.preferredWidth: Sizing.px(34)
                            horizontalAlignment: Text.AlignRight
                            text: modelData.pct + "%"
                            color: Colors.fg
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }

            // Quick toggles — 2×2 grid. Each tile is a micro-button:
            // icon + label + active accent when on. Clicking flips the
            // underlying Ui flag; services read the flag reactively.
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: Spacing.xs
                columns: 2
                rowSpacing: Spacing.sm
                columnSpacing: Spacing.sm

                // DND — silence notifications.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(44)
                    radius: Shape.radiusSm
                    color: Ui.dndOn ? Colors.accent
                           : (dndHover.containsMouse ? Colors.tileBgActive
                                                      : Colors.bgAlt)
                    Behavior on color { CAnim { type: "fast" } }
                    Row {
                        anchors.centerIn: parent
                        spacing: Spacing.sm
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Ui.dndOn ? "\uf1f7" : "\uf0f3"   // bell-slash / bell
                            color: Ui.dndOn ? Colors.bgAlt : Colors.fg
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontCaption
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Do Not Disturb"
                            color: Ui.dndOn ? Colors.bgAlt : Colors.fg
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                        }
                    }
                    MouseArea {
                        id: dndHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.dndOn = !Ui.dndOn
                    }
                }

                // Caffeine — inhibit idle.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(44)
                    radius: Shape.radiusSm
                    color: Ui.caffeineOn ? Colors.accent
                           : (caffHover.containsMouse ? Colors.tileBgActive
                                                       : Colors.bgAlt)
                    Behavior on color { CAnim { type: "fast" } }
                    Row {
                        anchors.centerIn: parent
                        spacing: Spacing.sm
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf0f4"   // coffee
                            color: Ui.caffeineOn ? Colors.bgAlt : Colors.fg
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontCaption
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Caffeine"
                            color: Ui.caffeineOn ? Colors.bgAlt : Colors.fg
                            font.family: Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                        }
                    }
                    MouseArea {
                        id: caffHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.caffeineOn = !Ui.caffeineOn
                    }
                }

                // Focus — pomodoro-ish timer ring.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(44)
                    radius: Shape.radiusSm
                    color: Ui.focusMode ? Colors.accentAlt
                           : (focusHover.containsMouse ? Colors.tileBgActive
                                                        : Colors.bgAlt)
                    Behavior on color { CAnim { type: "fast" } }
                    Row {
                        anchors.centerIn: parent
                        spacing: Spacing.sm
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf252"   // hourglass-half
                            color: Ui.focusMode ? Colors.bgAlt : Colors.fg
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontCaption
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Ui.focusMode ? Ui.focusTime : "Focus"
                            color: Ui.focusMode ? Colors.bgAlt : Colors.fg
                            font.family: Ui.focusMode ? Typography.fontMono
                                                       : Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                            font.features: ({ "tnum": 1 })
                        }
                    }
                    MouseArea {
                        id: focusHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.focusMode = !Ui.focusMode
                    }
                }

                // Recording — scripts flip Ui.recording; this tile is
                // a display+toggle. Clicking when off flips on but the
                // user still has to start the recorder; clicking when on
                // flips off.
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Sizing.px(44)
                    radius: Shape.radiusSm
                    color: Ui.recording ? Colors.critical
                           : (recHover.containsMouse ? Colors.tileBgActive
                                                      : Colors.bgAlt)
                    Behavior on color { CAnim { type: "fast" } }
                    Row {
                        anchors.centerIn: parent
                        spacing: Spacing.sm
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(8); height: Sizing.px(8)
                            radius: width / 2
                            color: Ui.recording ? Colors.bgAlt : Colors.critical
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Ui.recording ? Ui.recordingTime : "Record"
                            color: Ui.recording ? Colors.bgAlt : Colors.fg
                            font.family: Ui.recording ? Typography.fontMono
                                                       : Typography.fontSans
                            font.pixelSize: Typography.fontMicro
                            font.weight: Typography.weightMedium
                            font.features: ({ "tnum": 1 })
                        }
                    }
                    MouseArea {
                        id: recHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.recording = !Ui.recording
                    }
                }
            }

            Item { Layout.fillHeight: true }   // push session row to bottom

            // Session row — Lock / Suspend / Power menu. Shell out via
            // standard loginctl / qs ipc so behavior matches the rest of
            // the shell.
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Spacing.md
                IconButton {
                    width: Sizing.px(36); height: Sizing.px(36)
                    radius: width / 2
                    color: Colors.bgAlt
                    icon: "\uf023"   // lock
                    iconSize: 12
                    onClicked: Quickshell.execDetached(
                        ["loginctl", "lock-session"])
                }
                IconButton {
                    width: Sizing.px(36); height: Sizing.px(36)
                    radius: width / 2
                    color: Colors.bgAlt
                    icon: "\uf186"   // moon
                    iconSize: 12
                    onClicked: {
                        Ui.collapse()
                        Quickshell.execDetached(
                            ["systemctl", "suspend"])
                    }
                }
                IconButton {
                    width: Sizing.px(36); height: Sizing.px(36)
                    radius: width / 2
                    color: Colors.bgAlt
                    icon: "\uf011"   // power
                    iconSize: 12
                    iconColor: Colors.critical
                    onClicked: {
                        Ui.collapse()
                        Quickshell.execDetached(
                            ["qs", "ipc", "call", "powermenu", "toggle"])
                    }
                }
            }
        }

        // ─── View toggle (expanded only) ──────────────────────────────
        // Top-right chrome glyph. Only shown when BOTH views have
        // something to offer — if there's no player, "system" is the
        // only place to go, and the glyph would be a no-op button.
        Rectangle {
            id: viewToggle
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Spacing.md
            anchors.rightMargin: Spacing.md
            width: Sizing.px(24); height: Sizing.px(24)
            radius: width / 2
            color: toggleHover.containsMouse ? Colors.tileBgActive
                                              : Colors.bgAlt
            visible: opacity > 0.01
            opacity: (root.state === "expanded" && root._expandable) ? 0.9 : 0
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.InOutSine }
            }
            Behavior on color { CAnim { type: "fast" } }

            Text {
                anchors.centerIn: parent
                // music note ↔ dashboard. Glyph flips to reflect the
                // view you'd SWITCH to on click, not the one you're on.
                text: Ui.expandedView === "media" ? "\uf0e4" : "\uf001"
                color: Colors.fg
                font.family: Typography.fontMono
                font.pixelSize: Typography.fontMicro
            }

            MouseArea {
                id: toggleHover
                anchors.fill: parent
                anchors.margins: -Sizing.px(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Ui.toggleExpandedView()
            }
        }

        // ─── Shared bottom-edge scrubber (peek tier) ──────────────────
        // Lives outside any state container so it's the stable anchor
        // for spatial continuity — the peek progress line and the
        // expanded scrubber read as the same bar at different scales.
        //
        // Visible only while peek-playing. Expanded uses its own in-flow
        // scrubber (more affordable with thumb + time labels), but the
        // two are bound to the same position/length so the eye tracks
        // one progress identity across the tier change.
        Rectangle {
            id: peekBottomTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Sizing.px(1.5)
            color: Colors.bgAlt
            visible: opacity > 0.01
            opacity: (root.peekActive && root.state === "playing") ? 0.55 : 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutSine }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * Math.max(0, Math.min(1,
                       ((root._player?.length ?? 0) > 0)
                           ? ((root._player?.position ?? 0) / root._player.length)
                           : 0))
                color: Colors.accent
                Behavior on width { Anim { type: "fast" } }
            }
        }
    }

    // ─── Source switch menu (right-click on playing island) ──────────
    // Lives outside the island rect so it can extend below the notch.
    // Mask includes its geometry when open (see mask binding above).
    Rectangle {
        id: sourceMenu
        anchors.top: island.bottom
        anchors.topMargin: Sizing.px(8)
        anchors.horizontalCenter: island.horizontalCenter
        width: Sizing.px(280)
        height: (root._playerCount * Sizing.px(46))
                + Sizing.px(40)       // footer (Auto-pick)
                + Spacing.sm * 2
        radius: Shape.radiusNormal
        color: Colors.card
        border.color: Colors.border
        border.width: Shape.borderThin
        visible: opacity > 0.01
        opacity: root.sourceMenuOpen ? 1 : 0
        scale: root.sourceMenuOpen ? 1.0 : 0.96
        transformOrigin: Item.Top
        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standardDecel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standardDecel
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Spacing.sm
            spacing: Sizing.px(2)

            Repeater {
                model: root.playerList
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isPinned:
                        Ui.pinnedPlayerIdentity === modelData.identity
                    readonly property bool isActive:
                        modelData === root._player
                    width: parent.width
                    height: Sizing.px(44)
                    radius: Shape.radiusSm
                    color: sourceRowHover.containsMouse ? Colors.tileBg
                           : (isActive ? Colors.bgSurface : "transparent")
                    Behavior on color { CAnim { type: "fast" } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Spacing.sm
                        anchors.rightMargin: Spacing.sm
                        spacing: Spacing.sm

                        // Art thumbnail
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(28); height: Sizing.px(28)
                            radius: Sizing.px(6)
                            color: Colors.bgSurface
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                visible: status === Image.Ready
                            }
                            Text {
                                visible: !(modelData.trackArtUrl)
                                anchors.centerIn: parent
                                text: "\uf001"   // nf-fa-music
                                color: Colors.fgMuted
                                font.family: Typography.fontMono
                                font.pixelSize: Typography.fontMicro
                            }
                        }

                        // Identity + track
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Sizing.px(28) - Sizing.px(20)
                                   - Spacing.sm * 2
                            spacing: 1
                            Text {
                                width: parent.width
                                text: modelData.identity ?? "Player"
                                color: Colors.fg
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontCaption
                                font.weight: Typography.weightDemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: (modelData.trackTitle && modelData.trackTitle.length)
                                      ? modelData.trackTitle : "—"
                                color: Colors.fgMuted
                                font.family: Typography.fontSans
                                font.pixelSize: Typography.fontMicro
                                elide: Text.ElideRight
                            }
                        }

                        // Pin / playing indicator
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Sizing.px(20)
                            horizontalAlignment: Text.AlignHCenter
                            text: isPinned ? "\uf08d"                 // pinned (fa-thumbtack)
                                  : (modelData.isPlaying ? "\uf04b"   // playing
                                                         : "\uf04c")  // paused
                            color: isPinned ? Colors.accent
                                   : (modelData.isPlaying ? Colors.success
                                                          : Colors.fgMuted)
                            font.family: Typography.fontMono
                            font.pixelSize: Typography.fontMicro
                        }
                    }

                    MouseArea {
                        id: sourceRowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.isPinned) Ui.unpinPlayer()
                            else Ui.pinPlayer(modelData.identity)
                            root.sourceMenuOpen = false
                        }
                    }
                }
            }

            // Footer: Auto-pick
            Rectangle {
                width: parent.width
                height: Sizing.px(36)
                radius: Shape.radiusSm
                color: autoHover.containsMouse ? Colors.tileBg : "transparent"
                border.color: Ui.pinnedPlayerIdentity === "" ? Colors.accent
                                                              : Colors.border
                border.width: Shape.borderThin
                opacity: Ui.pinnedPlayerIdentity === "" ? 1 : 0.8
                Behavior on color { CAnim { type: "fast" } }
                Row {
                    anchors.centerIn: parent
                    spacing: Spacing.xs
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf0b2"   // fa-arrows
                        color: Ui.pinnedPlayerIdentity === "" ? Colors.accent
                                                               : Colors.fgMuted
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Auto-pick"
                        color: Ui.pinnedPlayerIdentity === "" ? Colors.accent
                                                               : Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontMicro
                        font.weight: Typography.weightMedium
                    }
                }
                MouseArea {
                    id: autoHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.unpinPlayer()
                        root.sourceMenuOpen = false
                    }
                }
            }
        }
    }

    // Dismiss the source menu on any outside click.
    HyprlandFocusGrab {
        active: root.sourceMenuOpen
        windows: [root]
        onCleared: root.sourceMenuOpen = false
    }

    // ─── Active MPRIS player ─────────────────────────────────────────
    // Priority:
    //   1. User-pinned (Ui.pinnedPlayerIdentity — right-click source menu)
    //   2. First currently-playing
    //   3. First available
    // Pin auto-clears if the pinned player goes offline.
    readonly property var playerList: Mpris.players?.values ?? []
    readonly property MprisPlayer _player: {
        const list = playerList
        if (Ui.pinnedPlayerIdentity !== "") {
            const pinned = list.find(p => p.identity === Ui.pinnedPlayerIdentity)
            if (pinned) return pinned
        }
        const active = list.find(p => p.isPlaying)
        return active ?? (list[0] ?? null)
    }
    readonly property int _playerCount: playerList.length
    readonly property bool _multiSource: _playerCount > 1

    // Auto-unpin when the pinned player vanishes.
    onPlayerListChanged: {
        if (Ui.pinnedPlayerIdentity === "") return
        const still = playerList.find(p => p.identity === Ui.pinnedPlayerIdentity)
        if (!still) Ui.unpinPlayer()
    }

    // Source menu open flag — lifts the menu card below the island.
    property bool sourceMenuOpen: false

    readonly property bool _expandable: {
        const list = Mpris.players?.values ?? []
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying || list[i].canPlay) return true
        return false
    }

    function _fmtTime(seconds) {
        const s = Math.max(0, Math.floor(seconds))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // Position tick — any time the peek scrubber, the expanded scrubber,
    // or the expanded time labels are visible, we need sub-second updates.
    Timer {
        interval: 1000
        running: root.state === "expanded"
                 || (root.state === "playing" && (root._player?.isPlaying ?? false))
        repeat: true
        triggeredOnStart: true
        onTriggered: root._player?.positionChanged()
    }

    Timer {
        id: clockTick
        property date time: new Date()
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: time = new Date()
    }

    // ─── Auto-dismiss timers for ephemeral states ────────────────────
    Timer {
        id: volumeTimer
        interval: 1200
        onTriggered: Ui.showVolume = false
    }
    Connections {
        target: Ui
        function onVolumePulseChanged() { volumeTimer.restart() }
    }
    Timer {
        id: toastTimer
        interval: 4000
        onTriggered: Ui.showToast = false
    }
    Connections {
        target: Ui
        function onShowToastChanged() { if (Ui.showToast) toastTimer.restart() }
    }

    // ─── Dismiss on outside click (expanded only) ────────────────────
    // TEMP: FocusGrab disabled for screenshot verification. Re-enable
    // after confirming visual renders correctly.
    HyprlandFocusGrab {
        active: false   // was: Ui.expanded
        windows: [root]
        onCleared: Ui.collapse()
    }

    // ─── Keyboard control in expanded mode ───────────────────────────
    // The "beat Apple" move — a desktop notch with real keyboard power.
    // Scope: only when expanded, so shortcuts don't conflict with the
    // rest of the shell. Focus is refreshed on every expand via the
    // onIslandStateChanged hook below.
    //
    //   Tab         swap media ↔ system view
    //   Esc         collapse
    //
    //   Media view only:
    //     Space       play / pause
    //     ← / →       seek ±5 s
    //     Shift+←/→   previous / next track
    //     ↑ / ↓       volume ±5 %
    //     M           mute toggle
    //     S           shuffle toggle
    //     R           cycle repeat (none → all → one → none)
    //
    //   System view only:
    //     D           DND toggle
    //     C           Caffeine toggle
    //     F           Focus toggle
    //     ↑ / ↓       volume ±5 %  (shared)
    FocusScope {
        id: expandedKeys
        anchors.fill: parent
        focus: root.state === "expanded"
        enabled: root.state === "expanded"

        Keys.onPressed: event => {
            const p = root._player
            const sink = Pipewire.defaultAudioSink?.audio
            const seekStep = 5
            const volStep = 0.05
            const inMedia = Ui.expandedView === "media"

            switch (event.key) {
                case Qt.Key_Escape:
                    Ui.collapse()
                    event.accepted = true
                    break
                case Qt.Key_Tab:
                    if (root._expandable) Ui.toggleExpandedView()
                    event.accepted = true
                    break
                case Qt.Key_Space:
                    if (inMedia && p) p.togglePlaying()
                    event.accepted = true
                    break
                case Qt.Key_Left:
                    if (!inMedia || !p) break
                    if (event.modifiers & Qt.ShiftModifier) {
                        p.previous()
                    } else if (p.canSeek && p.length) {
                        p.position = Math.max(0, p.position - seekStep)
                    }
                    event.accepted = true
                    break
                case Qt.Key_Right:
                    if (!inMedia || !p) break
                    if (event.modifiers & Qt.ShiftModifier) {
                        p.next()
                    } else if (p.canSeek && p.length) {
                        p.position = Math.min(p.length, p.position + seekStep)
                    }
                    event.accepted = true
                    break
                case Qt.Key_Up:
                    if (sink) {
                        sink.volume = Math.min(1, sink.volume + volStep)
                        Ui.triggerVolume()
                    }
                    event.accepted = true
                    break
                case Qt.Key_Down:
                    if (sink) {
                        sink.volume = Math.max(0, sink.volume - volStep)
                        Ui.triggerVolume()
                    }
                    event.accepted = true
                    break
                case Qt.Key_M:
                    if (sink) sink.muted = !sink.muted
                    event.accepted = true
                    break
                case Qt.Key_S:
                    if (inMedia && p) p.shuffle = !p.shuffle
                    event.accepted = true
                    break
                case Qt.Key_R:
                    if (inMedia && p) p.loopState = (p.loopState + 1) % 3
                    event.accepted = true
                    break
                case Qt.Key_D:
                    if (!inMedia) Ui.dndOn = !Ui.dndOn
                    event.accepted = true
                    break
                case Qt.Key_C:
                    if (!inMedia) Ui.caffeineOn = !Ui.caffeineOn
                    event.accepted = true
                    break
                case Qt.Key_F:
                    if (!inMedia) Ui.focusMode = !Ui.focusMode
                    event.accepted = true
                    break
            }
        }
    }

    // Focus hand-off is timing-sensitive. The sequence that must happen
    // for keystrokes to reach the FocusScope:
    //
    //   1. Ui.expanded flips true
    //   2. WlrLayershell.keyboardFocus goes OnDemand (layer-shell commit)
    //   3. Compositor routes next key events to this window
    //   4. Qt's FocusScope claims active focus inside the window
    //
    // Step 4 won't happen on its own if Qt considered some other Item
    // focused last. `forceActiveFocus()` nails it down. The first call
    // fires on the same event-loop tick as the flag flip, before the
    // layer-shell commit has even made it to the compositor — so we
    // schedule a second call via a zero-interval Timer (Qt.callLater
    // equivalent) after the next tick, and a third ~80 ms later as a
    // backstop. Triple-tap because this race has cost us twice already;
    // one `forceActiveFocus` at the right moment is cheap, three are
    // harmless.
    Timer {
        id: focusRetry
        interval: 80
        repeat: false
        onTriggered: if (Ui.expanded) expandedKeys.forceActiveFocus()
    }
    Connections {
        target: Ui
        function onExpandedChanged() {
            if (Ui.expanded) {
                expandedKeys.forceActiveFocus()
                Qt.callLater(() => {
                    if (Ui.expanded) expandedKeys.forceActiveFocus()
                })
                focusRetry.restart()
            }
        }
        function onExpandedViewChanged() {
            if (Ui.expanded) expandedKeys.forceActiveFocus()
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
}
