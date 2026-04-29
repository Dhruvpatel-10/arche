pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// IdleLock — owns hypridle's lifecycle. Single source of truth for the
// "auto-lock active" state, mirroring the caffeine pattern: a bool drives
// a Process binding, never the other way around.
//
// Why the shell owns hypridle (not hypr autostart): the old setup spawned
// hypridle from `exec-once` and toggled it via `pgrep -x` + `pkill -x` in
// a bash script. The script's notification text could lag the real state
// when uwsm-app/pkill timing skewed (notification said "enabled" while
// hypridle was actually still being torn down, or vice-versa). Binding
// `Process.running` to a QML bool removes that race — the process state
// IS the toggle state by construction.
//
// IPC:
//   qs ipc call idle toggle
//   qs ipc call idle on
//   qs ipc call idle off
//   qs ipc call idle status   -> "on" | "off"
QtObject {
    id: root

    // Single source of truth. Default true so a fresh shell load starts
    // with auto-lock active (matches old autostart behaviour).
    property bool enabled: true

    property Process _proc: Process {
        command: ["hypridle"]
        running: root.enabled
    }

    onEnabledChanged: {
        // Phrasing chosen for clarity over symmetry: "Auto-lock on" reads
        // unambiguously as "screen will lock when idle", whereas the
        // earlier "Idle lock enabled" got parsed by users as "anti-idle
        // lock is on → stay awake". Lead with the verb (locks / stays
        // awake) so the body confirms the consequence.
        const summary = enabled ? "Auto-lock on" : "Auto-lock off"
        const body    = enabled ? "Screen locks when idle"
                                : "Screen stays awake"
        Quickshell.execDetached([
            "notify-send", "-a", "arche-shell",
            "-i", enabled ? "system-lock-screen" : "system-lock-screen-off",
            summary, body
        ])
    }

    property IpcHandler _ipc: IpcHandler {
        target: "idle"
        function toggle(): void { root.enabled = !root.enabled }
        function on():     void { root.enabled = true }
        function off():    void { root.enabled = false }
        function status(): string { return root.enabled ? "on" : "off" }
    }
}
