# Quickshell — patterns we rely on

Internal cheat sheet. Captures the non-obvious bits of the Quickshell API that
shape this repo's structure. Source links and reference configs at the bottom.

## Layer-shell namespace

`PanelWindow` is a wlr-layer-shell surface. The compositor sees its `namespace`
field — Hyprland matches `layerrule` against it. Quickshell's default namespace
is the literal string `quickshell`.

Set it via the `WlrLayershell` attached property at construction (it cannot be
changed after `windowConnected`):

```qml
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.namespace: "arche-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto
}
```

**Why we care.** Hyprland's `layerrule = blur 1, match:namespace quickshell` will
blur every Quickshell surface unless you give it a unique namespace. A
fullscreen *transparent* surface (e.g. a click-outside catcher) under a blur
rule blurs the whole screen — see "Outside-click dismissal" below.

## Outside-click dismissal — use `HyprlandFocusGrab`, not a full-screen catcher

Quickshell's `PopupWindow` is an xdg-popup; it does not grab focus and has no
`closeOnOutsideClick`. The wrong way to add outside-click dismissal is a
fullscreen transparent `PanelWindow` with a `MouseArea` — it ends up matching
generic `layerrule` rules and blurs the whole screen.

The right way on Hyprland is `HyprlandFocusGrab` (uses the
`hyprland_focus_grab_v1` protocol — no overlay surface needed):

```qml
import Quickshell.Hyprland

PanelWindow {
    id: card
    visible: Ui.controlCenterOpen
    // ...sized to the card itself, not the screen...

    HyprlandFocusGrab {
        active: Ui.controlCenterOpen
        windows: [card]
        onCleared: Ui.controlCenterOpen = false
    }
}
```

Whitelist windows in `windows`; clicks anywhere else fire `cleared`. No layer
surface spans the screen, so no compositor rule can blur the whole screen.

For non-Hyprland compositors the fallback is a transparent fullscreen catcher
with a unique namespace so blur rules don't match it (noctalia's pattern). We
are Hyprland-only — focus-grab is the canonical answer.

## Notifications

`Quickshell.Services.Notifications.NotificationServer` exposes only the live
`trackedNotifications` model. When a notification is dismissed/expired/replaced
it falls out of that model — there is **no built-in history**.

Pattern (mirrors caelestia/shell):

1. In `onNotification`, set `n.tracked = true` (otherwise the server discards
   it immediately) and snapshot the fields you want into a plain JS object,
   pushed onto a capped history array.
2. Wire `n.closed.connect(reason => { ... })` to mark the history entry as
   dismissed if you want to differentiate. `NotificationCloseReason` values:
   `Expired`, `Dismissed`, `CloseRequested` (the last is also what fires when
   the app sends a replacement — replacement detection is done on the *new*
   notification by matching `id`).
3. Render the UI from the history array, not from `trackedNotifications`.

Live toasts are a separate concern — keep a short-lived `toasts` list with its
own auto-expire timer for the bottom-corner popup, independent of history.

## Process re-entrancy guards

`Process.running = true` on an already-running Process is a silent no-op — the
new `command` assignment is dropped. For any service where a poll tick could
arrive while the previous command is still in flight (`nmcli`, `bluetoothctl`,
`df`, `brightnessctl`), guard with:

```qml
if (!root.query.running) root.query.running = true
```

Services that share a single `Process` between multiple operations (connect /
disconnect on the same `Process`, for instance) must guard even harder — the
caller has no feedback that its command was dropped, so the second call
silently loses its work. See `services/Net.qml` `connectTo`/`disconnect`,
`services/Bt.qml` `connectDevice`/`disconnectDevice`.

## Drawer dismissal recipe (ControlCenter / CalendarPanel)

Every drawer needs three independent dismissal paths — and only one of them
should be a MouseArea. The trap: a scrim `MouseArea { onContainsMouseChanged }`
fires the instant the drawer becomes visible (because `containsMouse` flips
true under the cursor before the card has settled), which starts the close
timer before the user has seen the drawer. Let the *card*'s `HoverHandler` own
the grace-period close; the scrim owns click-outside; a `FocusScope` with
`Keys.onEscapePressed` owns Esc.

```qml
StyledWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Follow focused monitor. No separate onFocusedMonitorChanged handler —
    // the binding below re-evaluates and the panel simply hops.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        return Quickshell.screens.find(s => s.name === fm.name) ?? null
    }

    FocusScope {                // Esc
        anchors.fill: parent
        focus: root.shouldBeActive
        Keys.onEscapePressed: Ui.drawerOpen = false
    }
    MouseArea {                 // click-outside
        anchors.fill: parent
        onClicked: Ui.drawerOpen = false
    }
    Rectangle { /* card */
        HoverHandler {          // grace-period close (card only)
            onHoveredChanged: hovered ? leaveTimer.stop() : leaveTimer.restart()
        }
    }
}
```

## Mpris.players — never cache

`Mpris.players` is a QML model; `.values` is an array proxy that invalidates
on every player add/remove. Cached references (`property var active:
Mpris.players.values.find(...)`) go stale. Always express the "active player"
as a derived binding so QML re-evaluates on model reset:

```qml
readonly property MprisPlayer player: {
    const list = Mpris.players?.values
    if (!list || list.length === 0) return null
    for (let i = 0; i < list.length; i++)
        if (list[i].isPlaying) return list[i]
    return list[0]
}
```

## Reference configs

We grep these when stuck:

- caelestia/shell — single-list notif model, focus-grab on drawers
- noctalia-dev/noctalia-shell — split popup/history models, fullscreen-catcher
  fallback for non-Hyprland

Cloned in `/tmp/qs-ref-caelestia` and `/tmp/qs-ref-noctalia` (regenerate with
`git clone --depth 1 …` when needed).

## Links

- PanelWindow: https://quickshell.org/docs/types/Quickshell/PanelWindow/
- WlrLayershell: https://quickshell.org/docs/types/Quickshell.Wayland/WlrLayershell/
- PopupWindow: https://quickshell.org/docs/types/Quickshell/PopupWindow/
- HyprlandFocusGrab: https://quickshell.org/docs/types/Quickshell.Hyprland/HyprlandFocusGrab/
- NotificationServer: https://quickshell.org/docs/types/Quickshell.Services.Notifications/NotificationServer/
- NotificationCloseReason: https://quickshell.org/docs/types/Quickshell.Services.Notifications/NotificationCloseReason/
