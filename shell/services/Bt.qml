pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bt — connected-device name + adapter power, polled every 5s. Covers the
// bar pill and control-center. One instance per shell.
QtObject {
    id: root
    property string device: ""
    property bool connected: false
    property bool powered: false

    // Connected device name
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

    property Timer timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.queryConn.running = true
            root.queryPower.running = true
        }
    }
}
