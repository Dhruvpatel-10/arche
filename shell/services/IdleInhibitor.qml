pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// IdleInhibitor — Caffeine. While `active` is true, keeps a
// `systemd-inhibit` subprocess alive holding the `idle:sleep:handle-lid-switch`
// locks. Killing the process releases them.
//
// Wired into Ui.caffeineOn so the CC tile and any IPC/shortcut share one
// bit of state. Pattern from /tmp/shell services/IdleInhibitor.qml,
// slimmed to just the systemd-inhibit child (we don't need the Wayland
// protocol path — systemd-inhibit is enough on logind systems).
QtObject {
    id: root
    property bool active: false

    // Single long-running child. Killed by toggling `running: false`.
    property Process _proc: Process {
        command: [
            "systemd-inhibit",
            "--what=idle:sleep:handle-lid-switch",
            "--who=arche-shell",
            "--why=Caffeine",
            "--mode=block",
            "sleep", "infinity"
        ]
        running: root.active
    }
}
