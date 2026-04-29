import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "."
import "./osd"

// Shortcuts — cross-cutting IPC dispatch that doesn't belong inside any
// single service. Service-local handlers live inside the service itself
// (Notifs owns `notifs`, Clipboard owns `clipboard`); this file only
// hosts triggers that fan out across multiple producers, or that touch
// no service state at all.
//
// Pattern from /tmp/shell (Caelestia): co-locate IPC with the thing it
// controls; reserve the global `Shortcuts` for what genuinely has no
// owner. Makes `grep -r IpcHandler` land on the right file every time.
//
// ─── IPC manifest ──────────────────────────────────────────────────────
// Every target registered by the shell, in one place. Keep in sync with
// the handlers below and in the service files — this list is the first
// stop when wiring a keybind or a script.
//
//   drawer     shell.qml          toggle/open/close → Ui.controlCenterOpen
//   calendar   shell.qml          toggle/open/close → Ui.calendarOpen
//   launcher   Launcher.qml       open / close / toggle
//   clipboard  Clipboard.qml      open / close / toggle
//   powermenu  PowerMenu.qml      open / close / toggle
//   notifs     Notifs.qml         dismissOne / clearAll
//   osd        Shortcuts.qml      volume / brightness
//   popover    Shortcuts.qml      show <name> / toggle <name> / close
//   media      Shortcuts.qml      popoverToggle / popoverOpen / popoverClose
//                                 (+ dialogToggle / dialogOpen / dialogClose
//                                 as back-compat aliases for older keybinds)
//   island     Shortcuts.qml      expand / collapse / focus / recording / peek
//                                 (legacy shims; island surface retired,
//                                 flags still flow through for scripts)
//   mpris      Shortcuts.qml      playPause / next / previous / volUp / mute …
//
// Discover live targets at runtime: `qs ipc show`.
Scope {
    // On-screen display — chained onto XF86Audio*/XF86MonBrightness*
    // bindings in stow/hypr/media.conf. Dispatches into per-kind
    // provider singletons (VolumeProvider, BrightnessProvider). Owned
    // here because the OSD is a rendering surface, not a service.
    IpcHandler {
        target: "osd"
        function volume():     void { OsdVolume.trigger() }
        function brightness(): void { OsdBrightness.trigger() }
    }

    // Living notch — user-driven state triggers for the center island.
    // `playing` is auto-derived from Mpris; `idle` is the fallback.
    // Everything else needs a real-world trigger wired from a script
    // or keybind:
    //
    //   qs ipc call island expand           # open full media player
    //   qs ipc call island collapse         # close it
    //   qs ipc call island focusToggle      # pomodoro / DND
    //   qs ipc call island recStart         # wf-recorder wrapper on-start
    //   qs ipc call island recStop          # wf-recorder wrapper on-stop
    //   qs ipc call island recTime 00:03:12 # wf-recorder tick
    //   qs ipc call island volume           # ephemeral volume peek
    //   qs ipc call island toast <s> <b>    # custom peek (smoke test)
    // Right-wing popovers — one mutually-exclusive string, exposed via
    // IPC so a keybind can `qs ipc call popover show audio`. Missing an
    // argument closes whatever's open.
    //
    //   qs ipc call popover show notifs    # open notifications
    //   qs ipc call popover toggle audio   # toggle audio mixer
    //   qs ipc call popover close          # dismiss current
    IpcHandler {
        target: "popover"
        function show(name: string):   void { Ui.rightPopover = name }
        function toggle(name: string): void { Ui.togglePopover(name) }
        function close():              void { Ui.closePopover() }
    }

    // Media popover — the compact now-playing card opened by clicking
    // the inline NowPlayingStrip in the Bar. IPC lets a keybind open it
    // without reaching for the mouse.
    //
    //   bind = SUPER, M, exec, qs ipc call media popoverToggle
    //
    // The `dialog*` variants are kept as aliases for the period when
    // this was mis-named MediaDialog — drop them once no keybinds in
    // stow/hypr/ reference them. Every function writes the same
    // `Ui.mediaPopoverOpen` flag so the two API names never drift.
    IpcHandler {
        target: "media"
        function popoverToggle(): void {
            Ui.mediaPopoverOpen = !Ui.mediaPopoverOpen
        }
        function popoverOpen():  void { Ui.mediaPopoverOpen = true }
        function popoverClose(): void { Ui.mediaPopoverOpen = false }

        // Back-compat aliases — will be removed after existing scripts
        // migrate to the popover* names.
        function dialogToggle(): void { popoverToggle() }
        function dialogOpen():   void { popoverOpen() }
        function dialogClose():  void { popoverClose() }
    }

    IpcHandler {
        target: "island"
        function expand():       void { Ui.tryExpand() }
        function collapse():     void { Ui.collapse() }
        function swapView():     void { Ui.toggleExpandedView() }
        function focusToggle():  void { Ui.focusMode = !Ui.focusMode }
        function focusOn():      void { Ui.focusMode = true }
        function focusOff():     void { Ui.focusMode = false }
        function focusTime(t: string):     void { Ui.focusTime = t }
        function recStart():     void { Ui.recording = true }
        function recStop():      void { Ui.recording = false }
        function recTime(t: string):       void { Ui.recordingTime = t }
        function volume():       void { Ui.triggerVolume() }
        function toast(summary: string, body: string): void {
            Ui.triggerToast({ summary: summary, body: body,
                              appName: "island", appIcon: "" })
        }
    }

    // MPRIS global control — lets keybinds and scripts drive whichever
    // player the island considers "active" (user-pinned, else first
    // playing, else first available). Unlike `playerctl`, these helpers
    // also ping the island's volume peek / trigger chrome when
    // appropriate, so a `qs ipc call mpris volUp` keystroke both changes
    // the volume AND pops the notch's volume tier.
    //
    // Examples:
    //   bind = SUPER SHIFT, Right, exec, qs ipc call mpris next
    //   bind = SUPER SHIFT, Left,  exec, qs ipc call mpris previous
    //   bind = SUPER SHIFT, Space, exec, qs ipc call mpris playPause
    //   bind = SUPER SHIFT, Up,    exec, qs ipc call mpris volUp
    //   bind = SUPER SHIFT, Down,  exec, qs ipc call mpris volDown
    //   bind = SUPER SHIFT, M,     exec, qs ipc call mpris mute
    // Helper for the mpris handler below. Kept outside IpcHandler so it
    // isn't exposed as a callable IPC function — Quickshell promotes
    // every `function` inside IpcHandler into the wire protocol, even
    // underscore-prefixed ones.
    QtObject {
        id: mprisHelpers
        function pick() {
            const list = Mpris.players?.values ?? []
            if (!list.length) return null
            if (Ui.pinnedPlayerIdentity !== "") {
                const pinned = list.find(p =>
                    p.identity === Ui.pinnedPlayerIdentity)
                if (pinned) return pinned
            }
            return list.find(p => p.isPlaying) ?? list[0]
        }
    }

    IpcHandler {
        target: "mpris"

        function playPause(): void {
            const p = mprisHelpers.pick(); if (p) p.togglePlaying()
        }
        function next():      void { const p = mprisHelpers.pick(); if (p) p.next() }
        function previous():  void { const p = mprisHelpers.pick(); if (p) p.previous() }

        function seekForward(): void {
            const p = mprisHelpers.pick()
            if (!p || !p.canSeek || !p.length) return
            p.position = Math.min(p.length, p.position + 5)
        }
        function seekBack(): void {
            const p = mprisHelpers.pick()
            if (!p || !p.canSeek || !p.length) return
            p.position = Math.max(0, p.position - 5)
        }

        function shuffle(): void {
            const p = mprisHelpers.pick(); if (p) p.shuffle = !p.shuffle
        }
        function loop(): void {
            const p = mprisHelpers.pick()
            if (p) p.loopState = (p.loopState + 1) % 3
        }

        function volUp(): void {
            const s = Pipewire.defaultAudioSink?.audio
            if (!s) return
            s.volume = Math.min(1, s.volume + 0.05)
            Ui.triggerVolume()
        }
        function volDown(): void {
            const s = Pipewire.defaultAudioSink?.audio
            if (!s) return
            s.volume = Math.max(0, s.volume - 0.05)
            Ui.triggerVolume()
        }
        function mute(): void {
            const s = Pipewire.defaultAudioSink?.audio
            if (s) { s.muted = !s.muted; Ui.triggerVolume() }
        }
    }
}
