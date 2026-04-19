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
