pragma Singleton
import QtQuick
import Quickshell.Io
import "."

// BrightnessProvider — re-queries brightnessctl and pops the OSD.
//
// The shell's Brightness service polls every 2s, which is too slow for a
// keypress-driven OSD. The hypr binding runs `brightnessctl set 5%+` first
// and then `qs ipc call osd brightness`, so by the time trigger() runs the
// new value is already on disk; we just need to read it.
QtObject {
    id: root

    function trigger() {
        // Show immediately with the previous value so the pill is on screen
        // within the frame of the keypress; the bar animates to the new
        // value as soon as _read returns (~20–50ms later).
        Osd.show({ icon: "\uf185", percent: _lastPercent, variant: "normal" })
        _read.running = true
    }

    property int _lastPercent: 0

    property Process _read: Process {
        command: ["sh", "-c", "echo $(( $(brightnessctl g) * 100 / $(brightnessctl m) ))"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = parseInt(text.trim())
                if (isNaN(p)) return
                root._lastPercent = p
                Osd.show({ icon: "\uf185", percent: p, variant: "normal" })
            }
        }
    }
}
