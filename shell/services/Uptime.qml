pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Uptime — reads /proc/uptime and exposes a human-readable "up 3d 4h"
// string. Reloaded on a 60s timer (minute granularity is plenty; the
// user glances at this, they don't stopwatch it).
//
// refCount-gated: only polls when a component mounts `Ref { service:
// Uptime }`. See components/Ref.qml.
QtObject {
    id: root
    property int refCount: 0

    // Total seconds since boot, as a number.
    property real seconds: 0

    // "3d 4h" or "4h 12m" or "12m" — coarsest two units that fit.
    readonly property string human: {
        const s = Math.max(0, Math.floor(root.seconds))
        const d = Math.floor(s / 86400)
        const h = Math.floor((s % 86400) / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    property FileView _file: FileView {
        path: "/proc/uptime"
        onLoaded: {
            // First token of /proc/uptime is seconds-since-boot as float.
            const t = text().trim().split(/\s+/)[0]
            root.seconds = parseFloat(t) || 0
        }
    }

    property Timer timer: Timer {
        interval: 60 * 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root._file.reload()
    }
}
