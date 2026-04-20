---
name: quickshell-pitfalls
description: Silent-failure traps and visual-verification checklist for Quickshell/QML work on the arche shell. Auto-load before reviewing, debugging, or finalizing any change under /opt/arche/shell/ — covers issues that compile and run but render or behave wrong.
user-invocable: false
---

# Quickshell Pitfalls — Silent Failures & Verification

This is the "things that compile, run, and still ship a bug" checklist. Pair it with the main `quickshell` skill — that one covers the happy path, this one covers the ways a change passes syntax and still ships a regression.

Use this skill:
- Before declaring a QML change done.
- When reviewing a diff that touches shapes, masks, colors, or layer surfaces.
- When the shell loads but "looks wrong" or "isn't clickable".

---

## Silent Failure Traps

### 1. Parallel geometry files
When a component draws a filled shape *and* a stroke using two separate QML files (fill vs. border, or one visible + one click-mask), their path definitions are not programmatically linked. Changing one is invisible to the other at compile time; runtime shows mismatched fill vs. outline.

**Check:** `Grep` for the component name across `components/`. If >1 file defines the same silhouette, edit *all* of them or refactor to a single path source.

### 2. Coexisting color systems
Arche's new code reads from the `theme/` modules (`Colors.qml`, etc.) but the legacy `Theme.qml` facade still resolves. A file that imports both and references `Theme.accent` + `Colors.accent` compiles; if they drift, colors drift.

**Check:** Read the imports at the top of the file. Prefer the modular `theme/*` tokens. Don't introduce new `Theme.*` references.

### 3. Region masking / click-through
Interactive elements added to a layer window that uses a region mask become *visible but unclickable* if you forget to extend the mask list. No error, just a dead button.

**Check:** Search for `mask:` / `regions` in the file you're editing. Every new `MouseArea`, `TapHandler`, or input primitive must be in the hit region.

### 4. PathArc direction
`PathArc { direction: PathArc.Clockwise | Counterclockwise }` renders either way. Wrong direction takes the long way around: compiles, renders, looks broken (corner arcs sweep the wrong side).

**Check:** Read the existing arcs in the same shape file; match their direction and sweep before adding new ones.

### 5. qmldir registration
A new QML type in a folder that isn't listed in that folder's `qmldir` can't be imported — the error reads "module not installed", which looks like a missing package but is a registration gap.

**Check:** Every new `.qml` component that will be imported from another folder needs its name added to the folder's `qmldir`.

### 6. `WlrLayershell.namespace` as a binding
Namespace is construction-only. Setting it as a dynamic binding silently falls back to the default `quickshell` namespace — Hyprland layer rules that target specific namespaces then miss, or generic blur rules match and the whole screen blurs.

**Check:** `WlrLayershell.namespace: "arche-foo"` must be a constant string literal, not `: someCondition ? "a" : "b"`.

### 7. Fullscreen transparent click-catcher with default namespace
A common outside-click pattern — a fullscreen transparent `PanelWindow` under the drawer — *inherits* the default `quickshell` namespace if you forget to set one. Compositor blur rules match it and the whole screen blurs when the drawer opens.

**Check:** Every `PanelWindow` gets a unique namespace. Better: use `HyprlandFocusGrab` or the per-monitor scrim pattern from `components/ControlCenter.qml`.

### 8. Missing `n.tracked = true`
In the `NotificationServer.onNotification` handler, if you don't set `n.tracked = true` as the first line, the notification is discarded before you can snapshot it. The UI briefly shows nothing and you chase a phantom render bug.

**Check:** First line of every `onNotification` handler.

### 9. Racing `Behavior`s
Two `Behavior` blocks animating correlated properties (e.g., `opacity` and `y`) driven by separate triggers desync under load. Compiles, looks janky, no error.

**Check:** Drawers and OSDs must have *one* numeric driver (e.g., `offsetScale: open ? 0 : 1`) with multiple `Behavior`s reading from it. See `components/ControlCenter.qml:19`.

### 10. Service singleton `undefined` before `ready`
`Pipewire.defaultAudioSink.audio.volume`, `UPower.displayDevice.state`, etc., are `undefined` until the service reports `ready`. Writes silently no-op; reads return `undefined` and your computed bindings collapse to `NaN` or `"undefined"`.

**Check:** Guard writes with `if (Service.ready) { ... }`. For reads, bindings naturally re-evaluate when `ready` flips — but verify the fallback displayed value isn't embarrassing.

### 11. Single-instance widget on multi-monitor setup
A per-screen widget spawned as a single top-level `PanelWindow` appears only on the primary monitor. No warning.

**Check:** Wrap in `Variants { model: Quickshell.screens; SomeWindow { screen: modelData } }`.

### 12. Caching a reference across `Mpris.players` resets
`Mpris.players` is a model that resets on player add/remove. A cached `property var active: Mpris.players[0]` goes stale; UI binds to a dead object reference.

**Check:** Compute the active player in a binding (`Mpris.players.find(p => p.playbackState === MprisPlaybackState.Playing)`), don't cache.

### 13. `Process.command` shell expansion
`Process.command: ["echo $HOME"]` does **not** expand `$HOME`; `command` is argv, not a shell line. Need `["bash", "-lc", "echo $HOME"]`.

**Check:** If the command contains pipes, redirects, globs, or env vars, it must be invoked through a shell.

---

## Visual Verification Checklist

After any visual change, don't trust that "the panel didn't crash" means "it works". Verify in this order:

1. **Journal first.** `journalctl --user -u quickshell.service -f` — a QML error *anywhere* imported can prevent the whole shell from loading. If the journal is quiet, good.
2. **Reload strategy.**
   - Edits to existing `.qml` files: hot-reload picks them up on save.
   - New singleton, new `qmldir` entry, new type registration, C++ touching: `systemctl --user restart quickshell.service` or `just panel-restart`.
3. **Trigger the state you care about.** Prefer IPC over mouse sim: `qs ipc show` lists targets; `qs ipc call drawer toggle` flips state deterministically. Mouse simulation is flaky; IPC is not.
4. **Screenshot.** `grim -g "$(slurp)"` or `grim` full-screen. Open the image and actually look — don't rely on "it didn't error".
5. **Read the file back.** After an edit, `Read` the post-edit content once to confirm the diff applied where you meant it (esp. when editing across multiple shape files — see trap #1).
6. **Exercise dismissal paths.** Every drawer has at least three: click-outside, Esc, and (if applicable) toggle-keybind. Exercise all three before declaring done.
7. **Multi-monitor check.** If the shell is running with multiple screens, verify the new surface appears on the right screen(s). If only one monitor is attached right now, at minimum verify `Variants { model: Quickshell.screens }` is in place (trap #11).

---

## Debugging Order of Operations

When something is broken, work in this order — each step is cheaper than the next:

1. **`journalctl --user -u quickshell.service -f`** — QML syntax errors, binding loops, missing types all surface here with file:line.
2. **`qs ipc show`** — confirm your new `IpcHandler` target registered. If it's missing, `Shortcuts.qml` didn't reload or the handler errored out earlier in the file.
3. **Check imports at the top of the file.** Many "it doesn't render" bugs are a missing `import "../theme"` or `import Quickshell.Wayland`.
4. **Check the `qmldir`** of any folder you added a file to. Missing entries ≠ missing package.
5. **Grep for the prop/signal name** across `shell/` — "it's not updating" is often "two places set it, one overwrites the other".
6. **Binding loop?** Break the loop by making one side `readonly` derived from the other's source of truth. Two-way `property` assignments never end well.
7. **Animation cut mid-flight?** Trap #9 — collapse to one numeric driver.
8. **Only now** reach for the reference repos (`/tmp/qs-ref-caelestia`, `/tmp/qs-ref-noctalia`). They're for "I don't know how *anyone* solves this", not first-line debugging.

---

## Never Do

- `pkill quickshell` — use `systemctl --user restart quickshell.service` so the unit stays managed.
- Edit `shell/shell.qml`, `shell/theme/*`, `shell/Ui.qml`, or `shell/Shortcuts.qml` from a sub-agent — those are load-bearing and belong to the orchestrator (`quickshell-expert`).
- Introduce a new hex color, hardcoded px, or font size. If the role doesn't exist in `theme/*`, add the role first.
- Add a `GaussianBlur` or `MultiEffect` "for polish". Blur is off at the compositor on purpose; depth comes from shadow + surface contrast.
- Skip hooks on a commit. If `just test` fails, fix the underlying issue.

---

## Where to Record Discoveries

When you hit a non-obvious failure mode that future contributors will also hit, append a short note to `/opt/arche/shell/docs/quickshell-notes.md`. Don't document what the code already says; document the *why* behind the workaround.
