pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brightness — reads backlight percent on a 2s poll, exposes a setter
// that runs brightnessctl and updates the cached value optimistically so
// the slider doesn't jitter while the write is in flight.
//
// Write throttle: slider drags can hit set() 60 times per second. Each
// call updates the optimistic `percent` immediately but only restarts a
// 100 ms debounce timer. brightnessctl runs once the user pauses —
// turning a smooth drag from 60 process spawns into ~2. Pattern from
// /tmp/shell services/Brightness.qml.
QtObject {
    id: root
    property int percent: 0

    property int _queued: -1     // -1 = nothing pending
    property int _lastWritten: -1

    function set(p) {
        const clamped = Math.max(1, Math.min(100, Math.round(p)))
        root.percent = clamped          // optimistic update, no flicker
        if (clamped === root._lastWritten) return
        root._queued = clamped
        writeTimer.restart()
    }

    property Process query: Process {
        command: ["sh", "-c", "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]
        stdout: StdioCollector {
            onStreamFinished: root.percent = parseInt(text.trim()) || 0
        }
    }

    property Process setProc: Process {}

    property Timer writeTimer: Timer {
        interval: 100
        repeat: false
        onTriggered: {
            if (root._queued < 0 || root._queued === root._lastWritten) return
            root.setProc.command = ["brightnessctl", "set", root._queued + "%"]
            root.setProc.running = true
            root._lastWritten = root._queued
            root._queued = -1
        }
    }

    property Timer timer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.query.running = true
    }
}
