pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PowerMenu — data + lifecycle for the power menu surface.
//
// Actions are a static table here; the UI lives in
// components/PowerMenuDialog.qml and consumes `actions` + `open`.
// Each action carries an argv list executed via Process on accept;
// the dialog itself closes synchronously via hide() before the
// command runs, mirroring the pattern Clipboard uses for pick/remove.
QtObject {
    id: root

    property bool open: false

    // Each row: { id, label, icon, cmd }
    //   id    — stable key for ScriptModel diff
    //   icon  — Nerd-Font glyph (MesloLGS NF)
    //   cmd   — argv list passed to Process.command
    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "󰌾",  cmd: ["loginctl", "lock-session"] },
        { id: "sleep",    label: "Sleep",    icon: "󰒲",  cmd: ["systemctl", "suspend"]     },
        { id: "logout",   label: "Logout",   icon: "󰈆",  cmd: ["uwsm", "stop"]             },
        { id: "reboot",   label: "Reboot",   icon: "󰜉",  cmd: ["systemctl", "reboot"]      },
        { id: "shutdown", label: "Shutdown", icon: "󰐥",  cmd: ["systemctl", "poweroff"]    }
    ]

    function show()   { open = true  }
    function hide()   { open = false }
    function toggle() { open = !open }

    function run(action) {
        if (!action) return
        _proc.command = action.cmd
        _proc.running = true
        hide()
    }

    // ─── IPC ───────────────────────────────────────────────────────────
    // Target `powermenu`. Hyprland binding dispatches via
    //   qs ipc call powermenu toggle
    property IpcHandler _ipc: IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggle() }
        function show():   void { root.show() }
        function hide():   void { root.hide() }
    }

    property Process _proc: Process {}
}
