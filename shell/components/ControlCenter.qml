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

StyledWindow {
    id: root
    name: "controlcenter"

    // Single normalized driver (0 = fully open, 1 = fully off-screen).
    // Binding `shouldBeActive ? 0 : 1` + `Behavior on offsetScale` gives
    // coordinated slide + fade from one property — no racing behaviors on
    // opacity and topMargin. Pattern borrowed from /tmp/shell (Caelestia).
    readonly property bool shouldBeActive: Ui.controlCenterOpen
    property real offsetScale: shouldBeActive ? 0 : 1

    // Keep surface painted through the close animation so the slide isn't
    // cut short when the Ui flag flips off.
    visible: shouldBeActive || offsetScale < 1

    Behavior on offsetScale {
        Anim { type: "spatial" }
    }

    // Multi-monitor: bind the layer surface to the currently-focused
    // monitor so the drawer opens where the user is looking, not on
    // Quickshell.screens[0]. Same pattern as PickerDialog. Resolves
    // Hyprland's HyprlandMonitor to the matching ShellScreen by name.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (list[i].name === fm.name) return list[i]
        return null
    }

    // Full monitor (minus the bar) so a scrim MouseArea can dismiss on
    // click-outside. Because this PanelWindow lives on one screen only,
    // external monitors stay fully interactive.
    //
    // Quickshell's default ExclusionMode.Auto already shrinks this layer
    // out of the bar's exclusive zone, so parent.top is just below the bar
    // — no extra top margin needed.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    // OnDemand: Wayland grants keyboard focus when the pointer enters the
    // surface. The Item below grabs that focus and handles Escape.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Note: no focused-monitor-changed dismiss handler. The `screen`
    // binding above already follows Hyprland.focusedMonitor — when focus
    // shifts the drawer simply hops to the new monitor (matching
    // PickerDialog's UX). Close it via Esc, click-outside, or the toggle.

    // Escape dismissal. FocusScope pulls the layer's OnDemand keyboard
    // focus so Esc fires here. Transparent; doesn't consume mouse events.
    FocusScope {
        anchors.fill: parent
        focus: root.shouldBeActive
        Keys.onEscapePressed: Ui.controlCenterOpen = false
    }

    // Scrim: clicks anywhere outside the card dismiss the drawer. Clicks on
    // the card itself hit the card's own MouseArea first and never reach us.
    // Left button only — right-clicks on the scrim should fall through to
    // whatever lives underneath (context menus, etc.) rather than being
    // swallowed into a dismiss we didn't ask for.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Ui.controlCenterOpen = false
    }

    Rectangle {
        id: card
        // Pin the card to the top-right corner just below the bar.
        // topMargin drifts up off-screen as offsetScale approaches 1.
        anchors.top: parent.top
        anchors.topMargin: Spacing.xs
                           + (-card.height - Spacing.md) * root.offsetScale
        anchors.right: parent.right
        anchors.rightMargin: Spacing.md
        width: Sizing.px(420)
        height: body.implicitHeight + Spacing.lg * 2
        color: Colors.card
        radius: Shape.radiusLg
        border.color: Colors.border
        border.width: Shape.borderThin
        opacity: 1 - root.offsetScale

        // Swallow clicks on the card so the scrim's dismiss handler doesn't
        // fire for interactions inside the drawer. Child MouseAreas
        // (buttons, sliders) still get their events first.
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body
            anchors {
                fill: parent
                margins: Spacing.lg
            }
            spacing: Spacing.md

            // Header — clock / date / uptime / power
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Sizing.px(2)
                    Text {
                        text: Qt.formatTime(clockTick.time, "HH:mm")
                        color: Colors.fg
                        font { family: Typography.fontSans; pixelSize: Typography.fontDisplay; weight: Font.DemiBold }
                    }
                    Row {
                        spacing: Spacing.sm
                        Text {
                            text: Qt.formatDate(clockTick.time, "dddd, MMMM d")
                            color: Colors.fgMuted
                            font { family: Typography.fontSans; pixelSize: Typography.fontBody }
                        }
                        // Middot separator (U+2022) in fontCaption size so it rides
                        // the baseline and reads as an intentional rule, not a speck.
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u2022"
                            color: Colors.fgDim
                            opacity: Effects.opacityMuted
                            font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                        }
                        Text {
                            text: "up " + Uptime.human
                            color: Colors.fgDim
                            font { family: Typography.fontSans; pixelSize: Typography.fontBody }
                        }
                    }
                }
                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "\uf011"
                    iconColor: Colors.critical
                    onClicked: {
                        Ui.controlCenterOpen = false
                        Quickshell.execDetached(["arche-powermenu"])
                    }
                }
            }

            // Toggle grid
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: Spacing.smMd
                rowSpacing:    Spacing.smMd

                ToggleTile {
                    icon: Net.radioOn ? "\uf1eb" : "\uf6ac"
                    label: "Wi-Fi"
                    subtitle: Net.radioOn
                        ? (Net.connected ? Net.ssid : "On")
                        : "Off"
                    active: Net.radioOn
                    onClicked: Net.toggle()
                    onRightClicked: {
                        Ui.controlCenterOpen = false
                        Quickshell.execDetached(["arche-popup", "impala"])
                    }
                }
                ToggleTile {
                    icon: Bt.powered ? "\uf293" : "\uf294"
                    label: "Bluetooth"
                    subtitle: Bt.powered
                        ? (Bt.connected ? Bt.device : "On")
                        : "Off"
                    active: Bt.powered
                    onClicked: Bt.toggle()
                    onRightClicked: {
                        Ui.controlCenterOpen = false
                        Quickshell.execDetached(["arche-popup", "bluetui"])
                    }
                }
                ToggleTile {
                    icon: "\uf1f6"
                    label: "Do Not Dist..."
                    subtitle: Ui.dndOn ? "On" : "Off"
                    active: Ui.dndOn
                    onClicked: Ui.dndOn = !Ui.dndOn
                }
                ToggleTile {
                    icon: "\uf0f4"
                    label: "Caffeine"
                    subtitle: Ui.caffeineOn ? "Keeping awake" : "Off"
                    active: Ui.caffeineOn
                    // IdleInhibitor binds its systemd-inhibit process to
                    // Ui.caffeineOn — flipping Ui.caffeineOn is enough.
                    onClicked: Ui.caffeineOn = !Ui.caffeineOn
                }
            }

            ToggleTile {
                width: parent.width
                wide: true
                icon: "\uf030"
                label: "Screenshot"
                subtitle: "Capture Screen"
                onClicked: {
                    Ui.controlCenterOpen = false
                    Quickshell.execDetached(["arche-screenshot"])
                }
            }

            Rectangle {
                width: parent.width
                height: Shape.borderThin
                color: Colors.border
                opacity: Effects.opacitySubtle
            }

            SliderRow {
                width: parent.width
                icon: (Pipewire.defaultAudioSink?.audio?.muted ?? false) ? "\uf6a9" : "\uf028"
                value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                onMoved: v => { if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.volume = v }
                onRightClicked: {
                    Ui.controlCenterOpen = false
                    Quickshell.execDetached(["arche-popup", "wiremix"])
                }
            }

            SliderRow {
                width: parent.width
                icon: "\uf185"
                value: Brightness.percent / 100
                onMoved: v => Brightness.set(v * 100)
            }

            Rectangle {
                width: parent.width
                height: Shape.borderThin
                color: Colors.border
                opacity: Effects.opacitySubtle
            }

            // Stats row. 8 px between cards → subtract 2*gap from total
            // before dividing into three columns.
            Row {
                width: parent.width
                spacing: Spacing.smMd
                readonly property int _cardWidth: (parent.width - spacing * 2) / 3
                StatCard { width: parent._cardWidth; icon: "\uf2db"; label: "CPU";  percent: SystemStats.cpu }
                StatCard { width: parent._cardWidth; icon: "\uf538"; label: "RAM";  percent: SystemStats.ram }
                StatCard { width: parent._cardWidth; icon: "\uf0a0"; label: "Disk"; percent: SystemStats.disk }
            }

            BatteryRow { width: parent.width }

            MediaCard { width: parent.width }

            NotificationsList { width: parent.width }
        }
    }

    Timer {
        id: clockTick
        property date time: new Date()
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: time = new Date()
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Keep SystemStats + Uptime polling only while the drawer is open.
    // See components/Ref.qml. The Loader only instantiates its Refs when
    // shouldBeActive flips true, and destroys them when closed.
    Loader {
        active: root.shouldBeActive
        sourceComponent: Item {
            Ref { service: SystemStats }
            Ref { service: Uptime }
        }
    }
}
