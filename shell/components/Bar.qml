import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import ".."
import "../services"

StyledWindow {
    id: bar
    name: "bar"
    property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bg

    // Left — workspace dots
    Workspaces {
        id: workspaces
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 14
        }
    }

    // Left-of-center — active window title. Trails the workspace dots
    // by a gap so the eye groups them as "context on the left". Maxes
    // out before overlapping the clock pill.
    ActiveWindow {
        anchors {
            left: workspaces.right
            verticalCenter: parent.verticalCenter
            leftMargin: 14
        }
        maxTextWidth: Math.max(80, (clockPill.x - workspaces.x - workspaces.width - 40))
    }

    // Center — clock + date, click to toggle calendar
    Pill {
        id: clockPill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Text {
            text: Qt.formatTime(clockTick.time, "HH:mm")
            color: Theme.fg
            font {
                family: Theme.fontSans
                pixelSize: Theme.fontCaption
                weight: Font.DemiBold
                features: { "tnum": 1 }
            }
            Layout.alignment: Qt.AlignVCenter
        }
        Rectangle {
            Layout.preferredWidth: 1; Layout.preferredHeight: 12
            Layout.alignment: Qt.AlignVCenter
            color: Theme.border
        }
        Text {
            text: Qt.formatDate(clockTick.time, "ddd, MMM d")
            color: Theme.fgMuted
            font {
                family: Theme.fontSans
                pixelSize: Theme.fontCaption
                weight: Font.Medium
                features: { "tnum": 1 }
            }
            Layout.alignment: Qt.AlignVCenter
        }
        onClicked: Ui.calendarOpen = !Ui.calendarOpen
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

    // Right — status pills
    Row {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
        }
        spacing: 6

        // Pill 1 — Wi-Fi SSID + Bluetooth device
        Pill {
            Icon {
                size: 12
                text: Net.connected ? "\uf1eb" : "\uf6ac"
                color: Net.connected ? Theme.fg : Theme.fgMuted
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Net.ssid || "—"
                color: Theme.fg
                font {
                    family: Theme.fontSans
                    pixelSize: Theme.fontCaption
                    weight: Font.Medium
                    features: { "tnum": 1 }
                }
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 100
                elide: Text.ElideRight
            }
            Rectangle {
                visible: Bt.connected
                Layout.preferredWidth: 1
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter
                color: Theme.border
            }
            Icon {
                visible: Bt.connected
                size: 12
                text: "\uf293"
                color: Theme.fg
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                visible: Bt.connected
                text: Bt.device
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption; weight: Font.Medium }
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: 80
                elide: Text.ElideRight
            }
        }

        // Pill 2a — Brightness (scroll to adjust)
        Pill {
            Icon { size: 12; text: "\uf185"; color: Theme.fg; Layout.alignment: Qt.AlignVCenter }
            Text {
                text: Brightness.percent
                color: Theme.fg
                font {
                    family: Theme.fontSans
                    pixelSize: Theme.fontCaption
                    weight: Font.DemiBold
                    features: { "tnum": 1 }
                }
                Layout.alignment: Qt.AlignVCenter
            }
            onScrolled: delta => Brightness.set(Brightness.percent + delta * 5)
        }

        // Pill 2b — Volume (scroll to adjust)
        Pill {
            Icon {
                size: 12
                text: (Pipewire.defaultAudioSink?.audio?.muted ?? false) ? "\uf6a9" : "\uf028"
                color: Theme.fg
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
                color: Theme.fg
                font {
                    family: Theme.fontSans
                    pixelSize: Theme.fontCaption
                    weight: Font.DemiBold
                    features: { "tnum": 1 }
                }
                Layout.alignment: Qt.AlignVCenter
            }
            onScrolled: delta => {
                const sink = Pipewire.defaultAudioSink?.audio
                if (!sink) return
                sink.volume = Math.max(0, Math.min(1, sink.volume + delta * 0.05))
            }
        }

        // Pill 3 — Battery + settings gear
        Pill {
            Icon {
                size: 12
                text: "\uf240"
                color: {
                    if (!UPower.displayDevice.isPresent) return Theme.fgMuted
                    const p = UPower.displayDevice.percentage * 100
                    if (p < 15) return Theme.critical
                    if (p < 30) return Theme.warn
                    return Theme.fg
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: UPower.displayDevice.isPresent
                      ? Math.round(UPower.displayDevice.percentage * 100) + "%"
                      : "—"
                color: Theme.fg
                font {
                    family: Theme.fontSans
                    pixelSize: Theme.fontCaption
                    weight: Font.DemiBold
                    features: { "tnum": 1 }
                }
                Layout.alignment: Qt.AlignVCenter
            }
            Rectangle {
                Layout.preferredWidth: 1; Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter
                color: Theme.border
            }
            Icon { size: 12; text: "\uf013"; color: Theme.fgMuted; Layout.alignment: Qt.AlignVCenter }

            onClicked: Ui.controlCenterOpen = !Ui.controlCenterOpen
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
}
