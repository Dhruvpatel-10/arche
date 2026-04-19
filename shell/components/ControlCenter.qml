import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import ".."
import "../services"

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

    // Full monitor (minus the bar) so a scrim MouseArea can dismiss on
    // click-outside. This replaces HyprlandFocusGrab, which was global and
    // swallowed clicks on every monitor. Because this PanelWindow lives on
    // one screen only, external monitors stay fully interactive.
    //
    // Quickshell's default ExclusionMode.Auto already shrinks this layer
    // out of the bar's exclusive zone, so parent.top is just below the bar
    // — no extra top margin needed.
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    // Dismiss when the cursor moves to another monitor. Hyprland's
    // follow_mouse=1 (default) makes focusedMonitor track the cursor, so
    // hovering off this screen closes the drawer automatically.
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!Ui.controlCenterOpen) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                Ui.controlCenterOpen = false
        }
    }

    // Scrim: clicks anywhere outside the card dismiss the drawer. Clicks on
    // the card itself hit the card's own MouseArea first and never reach us.
    MouseArea {
        anchors.fill: parent
        onClicked: Ui.controlCenterOpen = false
    }

    Rectangle {
        id: card
        // Pin the card to the top-right corner just below the bar.
        // topMargin drifts up off-screen as offsetScale approaches 1.
        anchors.top: parent.top
        anchors.topMargin: 4 + (-card.height - 12) * root.offsetScale
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: Theme.controlCenterWidth
        height: body.implicitHeight + Theme.padLg * 2
        color: Theme.card
        radius: Theme.radiusLg
        border.color: Theme.border
        border.width: 1
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
                margins: Theme.padLg
            }
            spacing: 12

            // Header — clock / date / uptime / power
            RowLayout {
                width: parent.width
                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        text: Qt.formatTime(clockTick.time, "HH:mm")
                        color: Theme.fg
                        font { family: Theme.fontSans; pixelSize: Theme.fontSizeXL; weight: Font.DemiBold }
                    }
                    Row {
                        spacing: 8
                        Text {
                            text: Qt.formatDate(clockTick.time, "dddd, MMMM d")
                            color: Theme.fgMuted
                            font { family: Theme.fontSans; pixelSize: Theme.fontSize }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3; height: 3; radius: 1.5
                            color: Theme.fgDim
                        }
                        Text {
                            text: "up " + Uptime.human
                            color: Theme.fgDim
                            font { family: Theme.fontSans; pixelSize: Theme.fontSize }
                        }
                    }
                }
                IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    icon: "\uf011"
                    iconColor: Theme.critical
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
                columnSpacing: 8
                rowSpacing: 8

                ToggleTile {
                    icon: "\uf1eb"
                    label: "Wi-Fi"
                    subtitle: "Connected"
                    active: true
                }
                ToggleTile {
                    icon: "\uf293"
                    label: "Bluetooth"
                    subtitle: "On"
                    active: true
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
                    onClicked: {
                        Ui.caffeineOn = !Ui.caffeineOn
                        IdleInhibitor.active = Ui.caffeineOn
                    }
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

            Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

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

            Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

            Row {
                width: parent.width
                spacing: 8
                StatCard { width: (parent.width - 16) / 3; icon: "\uf2db"; label: "CPU"; percent: SystemStats.cpu }
                StatCard { width: (parent.width - 16) / 3; icon: "\uf538"; label: "RAM"; percent: SystemStats.ram }
                StatCard { width: (parent.width - 16) / 3; icon: "\uf0a0"; label: "Disk"; percent: SystemStats.disk }
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
