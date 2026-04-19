pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// SystemStats — CPU (delta-based, not a process count), RAM, disk. 2s
// poll.
//
// CPU + RAM read via FileView on /proc/stat and /proc/meminfo directly
// rather than shelling out — no fork-exec overhead per tick.
// Disk still uses df because there's no cheap /proc equivalent.
//
// refCount: consumers mount a `Ref { service: SystemStats }` to activate
// polling. When no one's watching the stats, the timer stops.
QtObject {
    id: root
    property int cpu: 0
    property int ram: 0
    property int disk: 0

    // Ref-count: incremented by components/Ref.qml, which decrements on
    // destroy. While zero, polling is off.
    property int refCount: 0

    property var _prev: ({ idle: 0, total: 0 })

    property FileView _cpuFile: FileView {
        path: "/proc/stat"
        onLoaded: {
            const m = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (!m) return
            const s = m.slice(1).map(n => parseInt(n, 10))
            const total = s.reduce((a, b) => a + b, 0)
            const idle = s[3] + (s[4] ?? 0)
            const dIdle = idle - root._prev.idle
            const dTotal = total - root._prev.total
            if (dTotal > 0) root.cpu = Math.round(100 * (1 - dIdle / dTotal))
            root._prev = { idle, total }
        }
    }

    property FileView _memFile: FileView {
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const mTotal = t.match(/MemTotal:\s*(\d+)/)
            const mAvail = t.match(/MemAvailable:\s*(\d+)/)
            if (!mTotal || !mAvail) return
            const total = parseInt(mTotal[1], 10) || 1
            const avail = parseInt(mAvail[1], 10) || 0
            root.ram = Math.round((total - avail) * 100 / total)
        }
    }

    property Process _dfProc: Process {
        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(\d+)%/)
                if (m) root.disk = parseInt(m[1], 10) || 0
            }
        }
    }

    property Timer timer: Timer {
        interval: 2000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._cpuFile.reload()
            root._memFile.reload()
            root._dfProc.running = true
        }
    }
}
