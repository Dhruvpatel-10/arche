pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bt — bluetooth adapter state + control. `device` is the currently
// connected peer's name; `powered` reflects the adapter switch. `toggle()`
// flips the adapter via `bluetoothctl power`.
//
// `devices` is a list of { mac, name, connected, paired, trusted } that
// the BluetoothPopover renders. Populated by `refreshDevices()`; kept
// scoped to the popover since polling the device list continuously for
// the bar pill is unnecessary. One instance per shell.
QtObject {
    id: root
    property string device: ""
    property bool connected: false
    property bool powered: false

    property var devices: []
    property string lastError: ""

    property Process queryConn: Process {
        command: ["sh", "-c", "for m in $(bluetoothctl devices Connected | awk '{print $2}'); do bluetoothctl info $m | awk -F': ' '/Name/{print $2; exit}'; done | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.device = text.trim()
                root.connected = root.device.length > 0
            }
        }
    }

    property Process queryPower: Process {
        command: ["sh", "-c", "bluetoothctl show | awk -F': ' '/Powered/{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: root.powered = text.trim() === "yes"
        }
    }

    // Lists paired devices and, for each, whether it's currently connected.
    // Format: MAC<TAB>NAME<TAB>CONNECTED(yes|no)
    property Process queryDevices: Process {
        command: ["sh", "-c",
            "paired=$(bluetoothctl devices Paired | awk '{print $2}'); "
            + "conn=$(bluetoothctl devices Connected | awk '{print $2}'); "
            + "for m in $paired; do "
            + "name=$(bluetoothctl info $m | awk -F': ' '/Name/{print $2; exit}'); "
            + "c=no; for x in $conn; do [ \"$x\" = \"$m\" ] && c=yes; done; "
            + "printf '%s\\t%s\\t%s\\n' \"$m\" \"$name\" \"$c\"; done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const parts = line.split("\t")
                    if (parts.length < 3 || !parts[0]) continue
                    list.push({
                        mac: parts[0],
                        name: parts[1] || parts[0],
                        connected: parts[2] === "yes",
                    })
                }
                // Connected first, then alphabetical.
                list.sort((a, b) => {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                root.devices = list
            }
        }
    }

    property Process toggler: Process {}
    property Process connecter: Process {
        stdout: StdioCollector { onStreamFinished: root.refreshSoon.restart() }
        stderr: StdioCollector {
            onStreamFinished: root.lastError = text.trim()
        }
    }

    function toggle() {
        const next = root.powered ? "off" : "on"
        root.powered = !root.powered
        toggler.command = ["bluetoothctl", "power", next]
        toggler.running = true
        refreshSoon.restart()
    }

    function refreshDevices() {
        if (!root.powered) { root.devices = []; return }
        if (root.queryDevices.running) return
        root.queryDevices.running = true
    }

    // Re-entry guard: `connecter` is shared between connect/disconnect.
    // Writing `command` + `running = true` while it's already running
    // silently no-ops — drop the call instead of swallowing it.
    function connectDevice(mac) {
        if (root.connecter.running) return
        root.lastError = ""
        root.connecter.command = ["bluetoothctl", "connect", mac]
        root.connecter.running = true
    }

    function disconnectDevice(mac) {
        if (root.connecter.running) return
        root.lastError = ""
        root.connecter.command = ["bluetoothctl", "disconnect", mac]
        root.connecter.running = true
    }

    // Re-entry guards: bluetoothctl usually returns in <50ms but stalls are
    // possible (dbus congestion, stuck adapter). Don't stomp a running query
    // with a fresh one — drop the tick instead.
    function _pollOnce() {
        if (!root.queryPower.running) root.queryPower.running = true
        if (!root.queryConn.running)  root.queryConn.running  = true
    }

    property Timer refreshSoon: Timer {
        interval: 600
        repeat: false
        onTriggered: {
            root._pollOnce()
            root.refreshDevices()
        }
    }

    property Timer timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._pollOnce()
    }
}
