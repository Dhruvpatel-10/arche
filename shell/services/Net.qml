pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Net — current wifi SSID, polled every 5s via nmcli. One instance per
// shell; the bar pill and anything else that wants it read this directly.
QtObject {
    id: root
    property string ssid: ""
    property bool connected: false

    property Process query: Process {
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,TYPE dev wifi | awk -F: '$1==\"yes\" && $3==\"\"{print $2; exit} $1==\"yes\"{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ssid = text.trim()
                root.connected = root.ssid.length > 0
            }
        }
    }

    property Timer timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.query.running = true
    }
}
