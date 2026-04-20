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
//
// Danger actions (reboot, shutdown) go through a two-step confirm.
// PowerMenu.run(action) checks action.danger:
//   • false → runs immediately (lock, sleep, logout)
//   • true  → stashes action in pendingAction, sets confirmOpen = true
//              so PowerMenuConfirm picks it up
// PowerMenu.confirm() executes pendingAction and clears state.
// PowerMenu.cancel()  clears state without running anything.
QtObject {
    id: root

    property bool open: false

    // ─── Confirm-step state ────────────────────────────────────────────
    // Owned here (not Ui) because these are domain-specific to the power
    // menu, not cross-component flags. Confirm dialog reads these to
    // render the title + body copy.
    property bool confirmOpen: false
    property var  pendingAction: null

    // Each row: { id, label, icon, cmd, danger }
    //   id     — stable key for ScriptModel diff
    //   icon   — Nerd-Font glyph (MesloLGS NF)
    //   cmd    — argv list passed to Process.command
    //   danger — true = requires confirm step before executing
    readonly property var actions: [
        { id: "lock",     label: "Lock",     icon: "󰌾",  cmd: ["loginctl", "lock-session"],  danger: false },
        { id: "sleep",    label: "Sleep",    icon: "󰒲",  cmd: ["systemctl", "suspend"],       danger: false },
        { id: "logout",   label: "Logout",   icon: "󰈆",  cmd: ["uwsm", "stop"],               danger: false },
        { id: "reboot",   label: "Reboot",   icon: "󰜉",  cmd: ["systemctl", "reboot"],        danger: true  },
        { id: "shutdown", label: "Shutdown", icon: "󰐥",  cmd: ["systemctl", "poweroff"],      danger: true  }
    ]

    function show()   { open = true  }
    function hide()   {
        // Also clear any pending confirm so the confirm surface
        // collapses with the picker rather than orphaning on screen.
        pendingAction = null
        confirmOpen   = false
        open = false
    }
    function toggle() { open = !open }

    function run(action) {
        if (!action) return
        if (action.danger) {
            // Stash and open the confirm dialog. The picker stays open so
            // dismissing the confirm (Esc / outside click / Cancel) returns
            // focus to the picker's search input automatically.
            pendingAction = action
            confirmOpen   = true
            return
        }
        // Non-danger: run immediately, close picker.
        _proc.command = action.cmd
        _proc.running = true
        hide()
    }

    function confirm() {
        if (!pendingAction) return
        _proc.command = pendingAction.cmd
        _proc.running = true
        pendingAction = null
        confirmOpen   = false
        hide()
    }

    function cancel() {
        pendingAction = null
        confirmOpen   = false
        // Picker stays open; focus returns automatically when the confirm
        // surface's visibility drops.
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
