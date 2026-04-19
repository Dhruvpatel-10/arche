---
name: quickshell
description: Quickshell (QML-based Wayland shell framework) — types, patterns, services, gotchas, and arche-specific conventions. Auto-load when editing QML under /opt/arche/shell/ or writing panels, drawers, overlays, OSDs, or shell widgets.
user-invocable: false
---

# Quickshell Skill

Quickshell is a QtQuick-based shell toolkit for Wayland compositors. You write QML; Quickshell provides the layer-shell surfaces, the reactive services (network, audio, notifications, media, power, tray, etc.), and the plumbing to talk to Hyprland / wlroots. Hot-reload on file save is first-class.

The arche shell lives at `/opt/arche/shell/`, symlinked to `~/.config/quickshell/` per user. The whole panel (bar, control center, calendar, clipboard, launcher, powermenu, toasts, OSD, notifications) runs in one Quickshell process per session.

## Philosophy

**Declarative, not imperative.** A QML component describes *what the UI is* given state — never write "on event X, call function Y to update Z". Bind properties to singletons (`Ui.controlCenterOpen`, `Net.ssid`, `Theme.accent`) and let Qt's property system re-render.

**One driver per animated transition.** A single numeric property (e.g. `offsetScale: shouldBeActive ? 0 : 1`) driving multiple visual `Behavior`s eliminates races between `opacity`, `scale`, `y`. See `components/ControlCenter.qml:19`.

**Role-named tokens, never values.** Colors are roles (`Colors.accent`, `Colors.tileBgActive`), not hexes. Sizes come from `Sizing.px()` / `Sizing.fpx()` so the shell scales cleanly between a 2.5K laptop and a 4K external. See `docs/theming.md`.

**Surfaces are layer windows; popups are xdg-popups.** Pick the right primitive: bars and drawers are `PanelWindow` (layer-shell); context menus anchored to a widget are `PopupWindow`. Don't stretch a `PanelWindow` across the full screen just to catch outside clicks — that's the common footgun (see Anti-Patterns).

**Peripheral, not replacement.** Contextual widgets (media island, notification toast, OSD) hang *off* the bar edge as their own layer windows. They appear when there's content and disappear when there isn't. They never replace stable, persistent UI (clock, workspaces, status pills). See `memory/feedback_ui_philosophy.md`.

---

## Core Types Cheat-Sheet

| Type | Module | Use when |
|------|--------|----------|
| `ShellRoot` | `Quickshell` | Top-level entry (one per shell process) |
| `PanelWindow` | `Quickshell` | Layer-shell surface: bars, drawers, OSDs, toasts |
| `PopupWindow` | `Quickshell` | Anchored xdg-popup relative to another window |
| `Variants` | `Quickshell` | Instantiate one component per screen/item |
| `LazyLoader` | `Quickshell` | Defer creating expensive components until needed |
| `IpcHandler` | `Quickshell.Io` | Expose functions to `qs ipc call` from keybinds/scripts |
| `Process` | `Quickshell.Io` | Spawn external commands, capture stdout/stderr |
| `FileView` | `Quickshell.Io` | Read/write files reactively |
| `SystemClock` | `Quickshell` | Reactive clock source (polling interval = seconds/minutes) |
| `WlrLayershell` | `Quickshell.Wayland` | Attached props on `PanelWindow` — layer, namespace, keyboardFocus |
| `HyprlandFocusGrab` | `Quickshell.Hyprland` | Dismiss-on-outside-click without a scrim surface |
| `Hyprland` | `Quickshell.Hyprland` | Focused monitor, workspaces, dispatch |
| `NotificationServer` | `Quickshell.Services.Notifications` | Receive desktop notifications |
| `SystemTray` | `Quickshell.Services.SystemTray` | StatusNotifierItem tray icons |
| `Mpris` | `Quickshell.Services.Mpris` | Media player control (play/pause, metadata, art) |
| `Pipewire` | `Quickshell.Services.Pipewire` | Audio sinks, volumes, node graph |
| `UPower` | `Quickshell.Services.UPower` | Battery, lid, AC state |

Always check the live API at https://quickshell.org/docs/ — Quickshell is pre-1.0 and signatures shift.

---

## Layer-shell Surface Recipe

```qml
import Quickshell
import Quickshell.Wayland

PanelWindow {
    WlrLayershell.namespace: "arche-controlcenter"  // unique — Hyprland layerrules match this
    WlrLayershell.layer: WlrLayer.Overlay            // Background | Bottom | Top | Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors { top: true; left: true; right: true }   // which screen edges
    exclusiveZone: height                            // reserve space (bar); 0 for overlays
    color: "transparent"                             // let QML Rectangles paint the surface
    visible: false                                   // drive from a state singleton
}
```

**Namespace matters.** Hyprland's `layerrule = blur 1, match:namespace <name>` targets by namespace. Default `quickshell` matches every surface — a fullscreen transparent catcher under a blur rule blurs the whole screen. Give every surface a unique namespace.

**Namespace is construction-only.** Cannot change after `windowConnected`. Set it as an attached property, not a binding.

---

## Outside-Click Dismissal

Two proven patterns — pick based on scope:

**Per-monitor scrim (arche default).** Make the drawer itself a full-monitor `PanelWindow` with `color: "transparent"` and a child `MouseArea` that sets `Ui.drawerOpen = false`. Keeps clicks on other monitors live. See `components/ControlCenter.qml:37-59`.

**`HyprlandFocusGrab`.** Uses `hyprland_focus_grab_v1`. No overlay surface. Whitelist windows; anything else clicked fires `onCleared`.

```qml
import Quickshell.Hyprland

HyprlandFocusGrab {
    active: Ui.drawerOpen
    windows: [drawerWindow]
    onCleared: Ui.drawerOpen = false
}
```

**Do not** add a fullscreen transparent `PanelWindow` *plus* keep the default namespace — compositor blur rules will match it and the whole screen will blur when the drawer opens.

---

## Services — Reactive, Don't Poll

Prefer service singletons over shelling out. When you must shell out, use `Process` with a `Timer` for polling — never a `setInterval`-style loop inside a component.

**Network.** Check what's in `services/Net.qml` first. Current arche uses `nmcli -t` via `Process` polled on a `Timer`. If Quickshell adds a first-class NetworkManager service, migrate.

**Notifications.** `NotificationServer` only exposes *live* `trackedNotifications`. On `onNotification`:

1. Set `n.tracked = true` (else server discards immediately).
2. Snapshot fields into a plain JS object on your own history array.
3. Wire `n.closed.connect(reason => ...)` — values: `Expired`, `Dismissed`, `CloseRequested` (the last also fires on app replacement).
4. Render UI from your history model, not from `trackedNotifications`.

See `Notifs.qml` + `components/NotificationsList.qml` + `components/Toast.qml`.

**Pipewire.** Access `Pipewire.defaultAudioSink.audio.volume` / `.muted`. Bind directly; writes to `volume` actually set the volume. Use `Pipewire.defaultAudioSink.ready` before touching properties — nodes flap on startup.

**Mpris.** `Mpris.players` is a model; iterate and pick the active one (`playbackState === MprisPlaybackState.Playing` first, else first). Don't cache a reference across model resets.

**SystemTray.** Iterate `SystemTray.items`. Each item has `.icon`, `.title`, `.menu`. For the menu, use `QsMenuOpener` + `QsMenuItem` from `Quickshell` — don't roll your own.

**UPower.** `UPower.displayDevice.percentage`, `.state` (`Charging | Discharging | Empty | FullyCharged`), `.timeToEmpty`.

---

## IPC — External Triggers

Keybinds and scripts dispatch into the shell via `qs ipc call <target> <func> [args...]`. Register targets with `IpcHandler`:

```qml
// Shortcuts.qml
IpcHandler {
    target: "drawer"
    function toggle() { Ui.controlCenterOpen = !Ui.controlCenterOpen }
    function open()   { Ui.controlCenterOpen = true }
    function close()  { Ui.controlCenterOpen = false }
}
```

Called from Hyprland: `bind = SUPER, N, exec, qs ipc call drawer toggle`.

Keep all handlers in `Shortcuts.qml` (single grep target). Handlers should only flip singleton state — no UI logic in the IPC layer.

---

## Process — Shelling Out

```qml
Process {
    id: proc
    command: ["bash", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | awk -F: '$1==\"yes\"{print $2}'"]
    running: false
    stdout: StdioCollector { onStreamFinished: root.ssid = text.trim() }
}

Timer { interval: 5000; repeat: true; running: true; onTriggered: proc.running = true }
```

Notes:
- `running: true` kicks off; it self-clears when done.
- `command` is `string[]` — *no shell expansion* unless you invoke a shell explicitly (`["bash", "-lc", ...]`).
- For continuous streams (e.g. `journalctl -f`), use `SplitParser` in `stdout`.

---

## Arche Shell Layout

```
/opt/arche/shell/
├── shell.qml           # ShellRoot — spawns per-screen Bar + singletons for drawers
├── Ui.qml              # singleton — cross-component open/closed flags
├── Theme.qml           # facade over theme/* — legacy callsites only
├── Shortcuts.qml       # all IpcHandler targets (grep entry point for IPC)
├── Notifs.qml          # NotificationServer + history model
├── Launcher.qml, Clipboard.qml, PowerMenu.qml  # domain state for dialogs
├── theme/
│   ├── Colors.qml, Typography.qml, Spacing.qml, Shape.qml, Sizing.qml,
│   │ Effects.qml, Motion.qml, qmldir
│   └── (new code imports these directly — don't add to Theme.qml facade)
├── components/         # visual pieces (Bar, Pill, ToggleTile, StatCard, etc.)
├── services/           # reactive data sources (Net, Bt, Brightness, SystemStats, etc.)
├── osd/                # OSD providers + Osd.qml overlay
└── docs/               # quickshell-notes.md, theming.md, typography.md
```

**Conventions:**
- New UI primitives go in `components/`; new data sources in `services/`.
- Import theme as `import "../theme"` and use `Colors.xxx`, `Typography.xxx`, etc. Don't reach for the `Theme` facade in new code.
- `StyledWindow` (in `components/`) is the per-drawer preset (transparent layer window, scrim, exit animation) — wrap it rather than building from `PanelWindow` directly when adding a new drawer.
- `Anim` and `CAnim` wrap the motion tokens (`Motion.durationFast/Med/Slow`, `Motion.easeOut/InOut/Spring`). Use them instead of raw `NumberAnimation`.
- State singletons (`Ui`, `Launcher`, etc.) own "drawer open?" flags; components never own inter-component state.

**Scaling:** `Sizing.px(n)` for layout integers (padding, radius, widths), `Sizing.fpx(n)` for font sizes. Both honor `ARCHE_SHELL_LAYOUT_SCALE` and `ARCHE_SHELL_FONT_SCALE` env vars.

**Blur is off at the compositor** (`layerrule = blur 0`). Depth through shadow + surface contrast. Don't reach for `GaussianBlur` / `MultiEffect` unless you've hit a case shadow can't solve — and then justify it in the commit.

---

## Testing & Iteration

**Hot reload:** quickshell watches file mtimes. Save → panel re-renders in-place. If a change requires a full restart (new singleton, new qmldir entry, C++-side issue):

```
systemctl --user restart quickshell.service
# or, if running bare:
just panel-restart
```

**Syntax check before commit:**
```
quickshell -p /opt/arche/shell/shell.qml --check   # if available
# or just start it and watch stderr for the QML error bubble
```

**Runtime inspection:** `qs ipc show` lists registered targets. `journalctl --user -u quickshell.service -f` for logs.

**Lint coverage:** `tests/run.sh` validates QML syntax for files under `/opt/arche/shell/`. Every new `.qml` must pass `just test`.

---

## Anti-Patterns (seen in this codebase or nearby)

1. **Fullscreen click-catcher `PanelWindow` with default namespace.** Compositor blur rules match `namespace=quickshell` — the entire screen blurs. Fix: unique namespace, or use `HyprlandFocusGrab`, or per-monitor scrim (`ControlCenter.qml` pattern).
2. **Racing behaviors.** `Behavior on opacity` + `Behavior on topMargin` animating simultaneously with `onFlag` mutating both — they desync. Fix: one numeric driver, multiple `Behavior`s reading from it.
3. **Embedding contextual widgets in `Bar.qml`.** Media island, timer, now-playing belongs in its own layer window hanging off the bar, not as a bar item. See feedback memory on UI philosophy.
4. **Polling what's reactive.** A `Timer` that runs `pamixer --get-volume` when `Pipewire.defaultAudioSink.audio.volume` is already bindable. Always check `Quickshell.Services.*` first.
5. **Forgetting `n.tracked = true`.** Notifications vanish before they render. Every `onNotification` needs `n.tracked = true` as the first line.
6. **Hardcoded hexes in components.** Use `Colors.*`. If the role doesn't exist, add it to `theme/Colors.qml` rather than inline a hex.
7. **Setting `WlrLayershell.namespace` as a binding.** Namespace is construction-only; attached properties only.
8. **Reaching for `GaussianBlur` because "the design looks flat".** We ship shadow + surface steps for depth. Blur looks cheap at our scale and fights the warm-industrial Ember aesthetic.

---

## Reference Configs (when a pattern isn't obvious)

Cloned in `/tmp/qs-ref-caelestia` and `/tmp/qs-ref-noctalia` — shallow-clone again when missing:

```
git clone --depth 1 https://github.com/caelestia-dots/shell          /tmp/qs-ref-caelestia
git clone --depth 1 https://github.com/noctalia-dev/noctalia-shell   /tmp/qs-ref-noctalia
```

Caelestia — single-list notif history, focus-grab drawers, polished animation tokens.
Noctalia — split popup/history notif models, fullscreen-catcher fallback for non-Hyprland compositors, richer widget library.

Neither is a template to copy. Read the relevant file, understand the pattern, then implement the arche version that fits our theme module split and `StyledWindow` conventions.

---

## Upstream Docs

- Quickshell docs: https://quickshell.org/docs/
- Types index: https://quickshell.org/docs/types/
- wlr-layer-shell protocol: https://wayland.app/protocols/wlr-layer-shell-unstable-v1
- Hyprland layer rules: https://wiki.hyprland.org/Configuring/Variables/#layerrule

The `/opt/arche/shell/docs/quickshell-notes.md` file captures the non-obvious patterns we rely on — keep it in sync when you discover a new one.
