pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// SystemStats — CPU (delta-based, not a process count), RAM, disk.
//
// Two timers:
//   * cpuMemTimer — 2s, reads /proc/stat + /proc/meminfo via FileView.
//     No fork-exec overhead per tick, so cheap to poll fast.
//   * diskTimer — 30s, shells out to df. Disk usage changes slowly;
//     polling every 2s wastes process spawns for a reading that barely
//     moves between ticks. 30s is still responsive enough that a large
//     file operation surfaces inside a typical drawer-open session.
//
// refCount: consumers mount a `Ref { service: SystemStats }` to activate
// polling. Both timers gate on refCount > 0. When no one's watching, all
// polling stops.
QtObject {
    id: root
    property int cpu: 0
    property int ram: 0
    property int disk: 0

    // Ref-count: incremented by components/Ref.qml, which decrements on
    // destroy. While zero, polling is off.
    property int refCount: 0

    // Poll intervals — named so the trade-off isn't buried in the Timer block.
    readonly property int _cpuMemIntervalMs: 2000    // /proc reads, no fork
    readonly property int _diskIntervalMs:   30000   // df spawn, keep slow

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

    // Fast poll: CPU + RAM only. Hits /proc files, no processes spawned.
    property Timer cpuMemTimer: Timer {
        interval: root._cpuMemIntervalMs
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root._cpuFile.reload()
            root._memFile.reload()
        }
    }

    // Slow poll: disk. Spawns df; keep infrequent. Re-entry guard in case
    // df is unusually slow (network mount, etc.) and the next tick arrives
    // while the previous is still running.
    property Timer diskTimer: Timer {
        interval: root._diskIntervalMs
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root._dfProc.running) return
            root._dfProc.running = true
        }
    }
}
