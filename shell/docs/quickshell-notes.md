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

## Hover-triggered popovers, retired — click-only is the clean answer

We previously ran a hover-to-open model on the media popover: a `NowPlayingStrip`
in the bar, a `MediaPopover` card below it, the cursor crossing the ~9 px gap
between them. All of the following were in the design to "make it clean":

- Two independent booleans (`mediaStripHovered`, `mediaCardHovered`) ORed
  together instead of a `+1/-1` counter (the counter drifted on race
  conditions).
- A 300 ms grace timer so the cursor could cross the gap without the popover
  snapping shut.
- A `HoverHandler { enabled: offsetScale === 0 }` gate on the card so a
  mid-animation card sliding through a stationary cursor couldn't fire a
  spurious `hovered=true` and oscillate the state.

Every mitigation fixed one edge case and introduced another. The gated handler
in particular produced a deadzone: if the cursor entered the gap and then
re-entered the card while `offsetScale > 0`, the card's `HoverHandler` was
disabled and couldn't set `hovered=true`, so the grace timer fired and closed
the popover — cursor physically over the card, flag read false.

Neither caelestia nor noctalia uses a bar-inline hover-triggered media popover;
both surface media through click-accessed panels. **Align with that.** The
current arche model is click-only:

- Click the strip → toggles `Ui.mediaPopoverOpen`.
- `qs ipc call media popoverToggle` from a keybind (back-compat alias
  `dialogToggle` still works until downstream scripts migrate).
- Escape / click-outside (via `HyprlandFocusGrab`) close it.

If a future feature genuinely needs hover-triggered card summoning, favour
keeping the summon element and the card as *one continuous hit surface* (no
gap) — so the close animation can't race cursor position — or accept
click-only.

See `components/MediaPopover.qml` + `components/NowPlayingStrip.qml` + the
single `mediaPopoverOpen` flag in `Ui.qml`.

## Bar exclusion zone — the unified bar owns its own reservation

Arche's top bar is a single full-width per-screen `PanelWindow` (`Bar.qml`)
anchored `top + left + right`. Because it already spans the entire top edge,
it can carry its own `exclusiveZone` and `ExclusionMode.Auto` — Hyprland
reserves the whole strip with no separate exclusion layer.

```qml
// components/Bar.qml
PanelWindow {
    WlrLayershell.namespace: "arche-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Auto
    anchors { top: true; left: true; right: true }
    color: "transparent"
    implicitHeight: Sizing.barHeightFor(_sn)
    exclusiveZone: Sizing.barHeightFor(_sn)
}
```

One per-screen `Bar` spawned from a `Variants { model: Quickshell.screens }`
block in `shell.qml`.

**Historical note (2026-04-20).** The previous design was three corner-anchored
wings (`BarLeftWing` + `BarCenterWing` + `BarRightWing`) plus a separate invisible
full-width `BarExclusionZone` to carry the reservation. The wings had different
anchor combos — the left/right wings were content-width (`top+left` or
`top+right`), so their individual `exclusiveZone` only reserved their own
footprint, leaving the center of the top edge unreserved. The dedicated
exclusion layer (pattern from caelestia's `Exclusions.qml` + noctalia's
`BarExclusionZone.qml`) worked around that. Once the bar unified into a single
full-width surface, the workaround was no longer needed — the bar reserves its
own footprint directly and the retired files were deleted.

## Duplicate property handlers are silently dropped

QML property-change handlers are *property assignments*, not event subscribers.
Declaring `onVisibleChanged:` twice on the same object replaces the first with
the second — the first block is dead code and no warning is emitted.

Bit us in `CalendarPanel.qml`: one `onVisibleChanged` reset view state on open,
a second one armed the cursor-away grace timer. Second silently clobbered the
first, so the calendar never reset to the current month when reopened.

Fix: every signal handler for a given property on a given object must be a
single block. If you have two unrelated behaviours, merge them, or attach one
via a `Connections { target: root; function onVisibleChanged() { … } }` block
(Connections handlers don't collide because they're on a separate target).

## Peripheral widgets vs drawer widgets — screen binding choice

Two working patterns:

1. **Per-screen surface via `Variants`** — `Bar`, `OsdOverlay`. The bar
   appears on every monitor. Use `_sn = screen?.name` and
   `Sizing.pxFor(..., _sn)` / `Sizing.fpxFor(..., _sn)` so a physically
   larger display can carry its own scale via `ARCHE_SHELL_LAYOUT_SCALE_<name>`.

2. **Focused-monitor single surface** — `CalendarPanel`, `MediaPopover`.
   One `PanelWindow`, `screen` bound to the Hyprland focused monitor, so
   the surface teleports. Use global `Sizing.px/fpx` — per-screen scale
   doesn't apply when the surface can live on any monitor.

3. **Visibility gate for content-dependent elements** — `NowPlayingStrip`
   (inline in the Bar's left cluster) sets `visible: hasActiveMedia` so the
   strip collapses to zero advance in its parent Row when no MPRIS player
   is registered. This is the "in-bar" flavour of the same pattern —
   contextual UI should never occupy space when there's nothing to show.
   For peripheral `PanelWindow`s the same gate applies at the surface
   level (hides the whole layer window — stops `HoverHandler`s, `Timer`s,
   and layer-shell reservations dead).

   Design note (2026-04-20): the previous `MediaPill` was a peripheral
   `PanelWindow` hanging below the bar on the focused monitor. It read as
   a dynamic island (centered, hover-expanding, dipping into app space).
   Retired in favour of the inline strip — the bar is now one flat top
   strip, and contextual "depth" comes from the drawer (`MediaPopover`)
   rather than from chrome protruding into workspace area.

## ArcheDialog base — one primitive for every modal and popover

Since the panel refresh on 2026-04-20, every dialog / popover surface in the
shell descends from `components/ArcheDialog.qml`. Two modes cover the full range:

- `mode: "modal"` — centered card, full-dim scrim, Exclusive keyboard focus,
  caller-sized. Consumers: `PowerMenuConfirm` (via the `StyledDialog` legacy
  shim), future confirmations and settings sheets. Animates with the
  `"dialog"` preset (200 ms, standard easing — calm, no overshoot; a
  destructive confirmation shouldn't bounce).
- `mode: "popover"` — edge-anchored card, transparent scrim (outside-click
  catcher), OnDemand focus, natural-height card. Consumers: the five
  right-wing popovers (via the `WingPopover` shim), `CalendarPanel`
  (`anchorEdge: "center"`), `MediaPopover` (`anchorEdge: "left"`). Every
  popover hangs directly below the bar — `anchorTopMargin` defaults to
  `Sizing.barHeight + Spacing.xs` in the base. The layer window is
  full-screen (anchors top+bottom+left+right, no exclusive zone), so a
  bare `Spacing.xs` would land the card on top of the bar. Consumers
  override the default only for deliberate special cases; there are
  none today. Animates with the `"spatial"` preset (500 ms,
  expressive-spatial overshoot — the alive "landing" feel the calendar
  always had is now the default for every anchored surface in the
  shell).

Animation driver:

```qml
// In ArcheDialog.qml — mode-aware
Behavior on offsetScale {
    Anim { type: root._isPopover ? "spatial" : "dialog" }
}
```

One `Behavior` on `offsetScale`, one preset chosen at binding time. Don't
introduce a second `Behavior` on `opacity` / `y` — they'd race the scale
driver (pitfall #9).

Anchor edges (popover mode):

- `"right"` — card pinned to the right edge, used by every wing popover
  via `WingPopover { anchorRightMargin: … }`.
- `"left"` — card pinned to the left edge. `MediaPopover` sits under the
  `NowPlayingStrip` in the left wing; `anchorSideMargin: Spacing.md`
  aligns with the strip's own left padding.
- `"center"` — `anchors.horizontalCenter: parent.horizontalCenter`. Used
  by `CalendarPanel`; card width is driven by the content
  (`view.calendarWidth`) so the whole grid lands centered under the
  clock pill.

Content-height chain in popover mode. `cardInterior`'s
`Layout.preferredHeight` reads `contentArea.childrenRect.height`, so every
content child needs an explicit `height` for the card to shrink to fit.
Both `CalendarView` (inside `CalendarPanel`) and the outer `Column` inside
`MediaPopover` set `height: implicitHeight` — the card auto-shrinks, no
manual `cardMaxHeight` tuning required.

Why one base:

- **Pitfall coverage in one place.** `ArcheDialog.qml`'s header lists the traps it
  covers (#1 parallel geometry, #3 masking, #6 namespace-as-binding, #7
  default-namespace catcher, #9 racing Behaviors). Fix a bug there, every
  surface inherits the fix.
- **One numeric driver.** `offsetScale: open ? 0 : 1` fans out to scrim
  opacity, card opacity, and card y-translate — never two `Behavior`s on
  correlated properties.
- **Unified dismissal signal.** `dismissed(reason)` fires on outside-click,
  Esc, cursor-leave, monitor-change, and any consumer-driven path
  (`"commit"`, `"cancel"`, `"action"`). Consumers grep one handler instead of
  three signals.

Shim components (back-compat):

- `components/StyledDialog.qml` — forwards the old `role` / `maxWidth` /
  `maxHeight` / `dangerDefault` API into `ArcheDialog { mode: "modal" }`. Kept
  so `PowerMenuConfirm` doesn't need a rewrite; new modal work should target
  `ArcheDialog` directly.
- `components/WingPopover.qml` — forwards `popoverId` / `anchorRightMargin`
  / `contentComponent` into `ArcheDialog { mode: "popover" }` and adds the
  scrollable `Flickable` wrapper that every right-wing popover wants.
  Click-only dismissal: outside-click / Esc / monitor-change. No
  cursor-leave timers — see "Hover-triggered popovers, retired" below.

Helper primitives (layout sugar used inside ArcheDialog's content slot):

- `components/dialog/DialogHeader.qml` — icon + title (+ optional subtitle
  + trailing slot) at a consistent weight. Matches the header rhythm the
  five existing right-wing popovers rebuild by hand today.
- `components/dialog/DialogSection.qml` — labeled content block, mirrors
  the `"Output" / "Applications" / "Networks"` uppercase-feel labels used
  in AudioMixer / Network / Battery popovers.
- `components/dialog/DialogDivider.qml` — 1 px rule at `Colors.separator`,
  `Effects.opacitySubtle`. Replaces the scatter of
  `Rectangle { width: …; height: 1; color: Colors.border; opacity: 0.5 }`
  seen across the right-wing popovers.

Interaction model — one across the whole panel:

- **Trigger:** click a pill / IPC call. No hover-triggered opens.
- **Dismissal:** outside-click, Esc, or focused-monitor change. No
  cursor-leave grace timers. The grace-timer pattern flickers at gap
  crossings (card sliding through a stationary cursor races the
  hit-test) and dead-zones when the card is physically under the cursor
  mid-animation but the `hovered` flag still reads false.
- **Screen binding:** single instance, `screen` bound to
  `Hyprland.focusedMonitor`. Per-screen `Variants` + a global open flag
  used to paint every instance on every monitor when the flag flipped —
  now avoided. Bars/OSDs stay per-screen because they're persistent UI,
  not triggered overlays.

Migration notes:

- `PickerDialog` stays specialized. It owns fuzzy-search + list + delegate
  contract machinery that doesn't belong in the base; the pitfall coverage
  inside PickerDialog predates ArcheDialog and is consistent with it. If a
  future picker variant simplifies enough to use ArcheDialog directly,
  migrate then.
- The five right-wing popovers
  (`NotificationsPopover`, `AudioMixerPopover`, `NetworkPopover`,
  `BluetoothPopover`, `BatteryPopover`) still consume `WingPopover`. They
  inherit all ArcheDialog pitfall coverage for free; their bespoke headers
  and sections can be migrated to `DialogHeader` / `DialogSection` /
  `DialogDivider` incrementally without touching the surface primitive.
- `CalendarPanel` and `MediaPopover` used to be standalone
  `StyledWindow` / `PanelWindow` subclasses that reimplemented scrim +
  Esc + focused-monitor teleport + slide animation each from scratch
  (and drifted slightly from one another). Both now extend `ArcheDialog`
  popover mode directly — not via a shim — so the window-level concerns
  live in one file. `CalendarPanel` still owns the calendar-specific
  state (`viewMonth` / `viewYear` / `selectedDate`, the 1 Hz clock
  `Timer`, and the paired fade-swap `SequentialAnimation` on month
  change); `MediaPopover` still owns the MPRIS player binding, the
  `hasActiveMedia` open gate, and the 1 s `positionChanged()` nudge
  timer for players that don't emit regular ticks (VLC, mpv, some
  browsers). The slide/fade feel is identical across calendar, media,
  and right-wing popovers because they all read the same `offsetScale`
  driver with the same `"spatial"` preset.
- `WingPopover`'s Flickable sizes itself explicitly rather than via
  `anchors.fill`. ArcheDialog's `contentArea` in popover mode uses
  `Layout.preferredHeight: childrenRect.height`; an `anchors.fill` Flickable
  would feed back into that preferredHeight and loop. Sizing reads the
  Loader's `implicitHeight` instead, clamped at `cardMaxHeight - 2 * contentPadding`.

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
