pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// IdleInhibitor — Caffeine side-effect service. While `Ui.caffeineOn` is
// true, keeps a `systemd-inhibit` subprocess alive holding the
// `idle:sleep:handle-lid-switch` locks. Killing the process releases them.
//
// `Ui.caffeineOn` is the single source of truth — toggle it there (CC tile,
// island notch, IPC) and this service reacts via the `running` binding. Do
// NOT assign to a local `active` flag here; that was the bug that made the
// island notch a no-op (two sources of truth drifting out of sync).
QtObject {
    id: root

    property Process _proc: Process {
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=arche-shell",
            "--why=Caffeine",
            "--mode=block",
            "sleep", "infinity"
        ]
        running: Ui.caffeineOn
    }
}
