pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

// Ui — cross-component open/closed flags + the living notch's state
// machine. See docs/quickshell-notes.md → "Island state derivation"
// for the precedence rules below.
QtObject {
    id: root

    // ─── Existing drawer flags ────────────────────────────────────────
    property bool controlCenterOpen: false
    // Opening the control center while a right-wing popover is open
    // causes two fullscreen Overlay surfaces to stack — the upper one
    // eats scrim clicks meant for the lower. Close any popover first.
    onControlCenterOpenChanged: if (controlCenterOpen) rightPopover = "none"
    property bool calendarOpen:      false
    property bool dndOn:             false
    property bool caffeineOn:        false

    // ─── Right-wing pill popovers ─────────────────────────────────────
    // One string flag, mutually exclusive. Each right-wing pill has its
    // own focused dialog instead of every pill opening ControlCenter.
    //
    //   "none"     no popover
    //   "notifs"   notifications center     (bell pill)
    //   "audio"    audio mixer + devices    (volume pill)
    //   "net"      wifi + network picker    (wifi pill)
    //   "bt"       bluetooth + devices      (bluetooth pill)
    //   "battery"  battery + profile + session (battery pill)
    property string rightPopover: "none"

    function togglePopover(name: string): void {
        rightPopover = (rightPopover === name) ? "none" : name
        // A focused popover replaces ControlCenter — close it to avoid
        // two layered drawers competing for attention.
        if (rightPopover !== "none") controlCenterOpen = false
    }
    function closePopover(): void { rightPopover = "none" }

    // ─── Living Notch state machine ───────────────────────────────────
    // Precedence (highest → lowest):
    //   expanded > toast > volume > recording > focus > playing > idle
    //
    // expanded / recording / focus are user-driven (click, IPC). They
    // stay on until flipped off explicitly.
    //
    // toast / volume are ephemeral (~4s / ~1.2s) — they overlay whatever
    // the underlying "persistent" state is and auto-dismiss back to it.
    //
    // playing is service-driven (Mpris) — whenever a player is Playing
    // and no higher state is active, the island shows the mini-player.
    //
    // idle is the resting state (clock + date).
    property bool recording: false
    property bool focusMode: false
    property bool expanded:  false

    // mm:ss labels driven by external providers (wf-recorder wrapper,
    // pomodoro script). The island binds display-only — if no provider
    // writes these, they show the defaults below.
    property string recordingTime: "00:00"
    property string focusTime:     "25:00"

    // Ephemeral flags — set by helper functions below, flip off on timer.
    property bool showVolume: false
    property bool showToast:  false

    // Toast payload (most recent notification peek).
    property var toastData: null   // { summary, body, appName, appIcon }

    // Derived: the currently-visible island state.
    readonly property string islandState: {
        if (expanded)  return "expanded"
        if (showToast) return "toast"
        if (showVolume) return "volume"
        if (recording) return "recording"
        if (focusMode) return "focus"
        // Playing iff any Mpris player is actually playing right now.
        for (const p of (Mpris.players?.values ?? [])) {
            if (p.isPlaying) return "playing"
        }
        return "idle"
    }

    // Pulse: consumers bind to this to auto-dismiss showVolume after a
    // key press. `triggerVolume()` bumps it, Island's Timer restarts.
    property int volumePulse: 0
    function triggerVolume(): void {
        showVolume = true
        volumePulse += 1
    }

    function triggerToast(data): void {
        toastData = data
        showToast = true
    }

    // Expanded content has two modes: the media player (when a Mpris
    // player is live) and a system panel (stats + quick toggles + session
    // actions). The island is a void that can disclose either — matching
    // the shell's philosophy that contextual UI is peripheral to persistent
    // UI, but also a place to *manage*, not just consume.
    //
    //   "media"   — media player (transport, scrubber, source pill)
    //   "system"  — stats row + quick toggles + session row
    //
    // tryExpand() always expands; the initial view tracks player state so
    // a click on a "playing" island opens the media view, a click on the
    // "idle" island opens the system view. User can flip via the in-card
    // toggle (header glyph) or Tab while focused.
    property string expandedView: "media"

    function tryExpand(): void {
        let hasPlayer = false
        for (const p of (Mpris.players?.values ?? [])) {
            if (p.isPlaying || p.canPlay) { hasPlayer = true; break }
        }
        expandedView = hasPlayer ? "media" : "system"
        expanded = true
    }

    function toggleExpandedView(): void {
        expandedView = (expandedView === "media") ? "system" : "media"
    }

    function collapse(): void { expanded = false }

    // ─── Pinned MPRIS player (source switch) ─────────────────────────
    // When multiple players are live (Spotify + browser), the island
    // picks one via its default rule (prefer playing, else first). The
    // user can override that via right-click → pick player. We pin by
    // identity because MPRIS object references can go stale across
    // model resets. Empty string = auto-pick.
    property string pinnedPlayerIdentity: ""
    function pinPlayer(identity: string): void { pinnedPlayerIdentity = identity }
    function unpinPlayer(): void { pinnedPlayerIdentity = "" }
}
