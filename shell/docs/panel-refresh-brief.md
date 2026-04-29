# Design Brief: Panel Visual Refresh + Adaptive Surface Opacity + Per-Screen Scaling

> **Archival note (2026-04-20).** This brief was written against the earlier
> three-wing bar architecture (`BarLeftWing` + `BarCenterWing` + `BarRightWing`
> + a separate `BarExclusionZone`). That design has since been unified into a
> single full-width `components/Bar.qml` that owns its own exclusive zone and
> composes the three clusters as anchored children (`BarWorkspaces`,
> `NowPlayingStrip`, `BarClock`, `BarStatusPills`). The *visual contracts*
> described below — adaptive opacity driver, per-screen `Sizing.pxFor` /
> `Sizing.fpxFor`, theme roles — remain accurate; only the per-surface file
> split is stale. See `quickshell-notes.md` → "Bar exclusion zone" for the
> current architecture.

## 1. Intent

When this lands, the bar stops feeling like a sticker pasted on the wallpaper and starts behaving like part of the compositor. On a tiled desktop it stays translucent and out of the way — the warm charcoal reads *through* a slight wash of the wallpaper below so the eye registers "layered surface" instead of "opaque hat". The moment a window takes over the workspace under that bar (maximized or true fullscreen), the surface firms up to near-solid so the chrome has its own ground, the amber accent stops fighting background noise, and the silhouette reads cleanly against whatever app is now beneath it. Typography sharpens: the workspace number gets a mono demi-weight so the active tile feels chiselled, status glyphs sit at a hair larger size so 18 pixels of pill actually contain a legible icon, and the separator stops being a ghost dot and starts being an intentional rule. Per-screen scaling lands defaults that are already tuned — laptop reads crisp at arm's length, external reads present at 80 cm — so the refresh lands the same way across both displays on first boot, without env-var twiddling.

## 2. Scope / Non-scope

**In scope (this brief):**
- Three bar `PanelWindow`s: `BarLeftWing`, `BarRightWing`, and the outer surface visuals of `IslandWindow` only where they share the adaptive-opacity chrome contract. The Island's internal state machine, expanded view, peek, breath, and mask are **untouched**.
- Workspace tiles (inside `BarLeftWing`), wing status pills (inside `BarRightWing`), separator glyphs, battery pill glyph.
- Per-screen layout/font scale defaults (new `Sizing.pxFor` / `Sizing.fpxFor` functions + env-var plumbing) and the existing global `Sizing.px` / `Sizing.fpx` fallback semantics.
- Adaptive opacity driver on each wing surface, reading `HyprlandWorkspace.hasFullscreen` for the monitor the wing is on.
- New theme roles (enumerated in §11) to be added by the orchestrator before coding starts.

**Peer designer owns:**
- `StyledDialog` primitive and any dialog/popover content redesign (`ControlCenter`, `CalendarPanel`, `*Popover.qml`, `PowerMenuDialog`, `LauncherDialog`, `ClipboardPicker`). No dialog chrome is touched here.

**Deferred:**
- Island internals, media scrubber, expanded view. The Island's outer `Colors.islandInk` fill stays — the notch is a void, not a surface, and does not participate in adaptive opacity.
- Legacy `components/Workspaces.qml` (grep confirms zero importers — leave it alone; any removal is a housekeeping commit, not this one).
- Starting the clock from scratch on the bar: see §6 for the decision.

## 3. Surfaces involved

Three surfaces, each per-screen via the existing `Variants { model: Quickshell.screens }` wrappers in `shell.qml`:

| File | Namespace (literal, construction-only) | Layer | Anchors | exclusiveZone | keyboardFocus | Visibility driver |
|------|---------------------------------------|-------|---------|---------------|---------------|-------------------|
| `BarLeftWing.qml`  | `"arche-bar-left"`  | `WlrLayer.Top` | top, left  | `Sizing.px(30)` (owns the row reservation for both wings) | `None` | always on |
| `BarRightWing.qml` | `"arche-bar-right"` | `WlrLayer.Top` | top, right | `0` | `None` | always on |
| `IslandWindow.qml` | `"arche-island"`    | `WlrLayer.Top` | top, left, right | `0` | existing (`OnDemand` while expanded) | existing |

Namespace strings must remain bare string literals — trap #6. The Left wing is the sole exclusive-zone owner to avoid double-counting; bar row height is a single token (§5).

## 4. State & data model

**Read from services:**
- `Hyprland.monitors.values` — indexed by `root.screen.name` to get the monitor that hosts this wing.
- `monitor.activeWorkspace.hasFullscreen` — reactive bool covering both fullscreen=1 (maximized) and fullscreen=2 (true-fullscreen). This is the adaptive trigger.
- `UPower.displayDevice.percentage`, `.state`, `.isPresent` — unchanged.
- `Pipewire.defaultAudioSink.audio` — unchanged.
- `Net`, `Bt`, `Notifs`, `Ui.recording`, `Ui.recordingTime` — unchanged.

**New per-surface local state** (no new global singletons needed):

```qml
// In each wing file:
readonly property var _mon: {
    const ms = Hyprland.monitors?.values ?? []
    const n  = root.screen?.name ?? ""
    return ms.find(m => m.name === n) ?? null
}
readonly property bool hasFullscreen:
    !!(_mon && _mon.activeWorkspace && _mon.activeWorkspace.hasFullscreen)

// The single driver.
property real opacityScale: hasFullscreen ? 1 : 0
Behavior on opacityScale { Anim { type: "standard" } }
```

Defaults: `opacityScale: 0` (translucent) so startup never flashes opaque. `_mon` may be `null` transiently during monitor hotplug — guarded by `?? null` and `!!(…)` in the binding; translucent is the safe fallback.

No `Ui.*` flag is added. This is per-wing derived state; promoting it to `Ui` would couple left and right wings on different screens into one boolean, which is wrong (two monitors, two workspaces, two independent fullscreen states).

## 5. Layout & sizing (per-screen)

Everything below routes through `Sizing.px()` / `Sizing.fpx()` today and will route through new `Sizing.pxFor(base, screenName)` / `Sizing.fpxFor(base, screenName)` once those land (§11). Components pass `root.screen?.name` as the second arg. If no per-screen override is present, the function falls back to global `Sizing.px` / `Sizing.fpx`.

**Bar row — shared.** `Sizing.pxFor(30, name)` stays as the wing row height. That is the floor; chrome that grows below uses `Sizing.pxFor(34, name)` (see pill height bump).

**Workspace tiles (BarLeftWing).**
- Tile side: `Sizing.pxFor(20, name)` (up from 18) — current 18 at 1.6× renders at ~29 px on laptop which is fine, but the active-tile number read as cramped in `laptop.png`; 20 gives the digit room and keeps tile-to-tile rhythm at `Spacing.xs` (4 px) gap.
- Radius: `Sizing.pxFor(6, name)` (up from 5) — keeps the 0.3 × tile ratio, reads more deliberate.
- Gap: `Sizing.pxFor(4, name)` (unchanged).
- Occupancy dot: `Sizing.pxFor(5, name)` at top-right with `-Sizing.pxFor(1, name)` margin — micro-bump to make the multi-window indicator visible on 4K where 4 px disappears.
- Arch glyph box: `Sizing.pxFor(16, name)` (up from 14) — the `\uf303` sits comfortably.
- Left inner padding: `Spacing.lg` (16 after scale) — unchanged.

**Wing pills (BarRightWing → `WingPill.qml`).**
- Pill height: `Sizing.pxFor(24, name)` (up from 22).
- Pill radius: `Shape.radiusPillWing` → `Sizing.pxFor(9, name)` (new token §11; current `Sizing.px(8)` at 1.6× = 13 which is *almost* fully round at height 22 — it reads like a blobby lozenge on the laptop).
- Horizontal padding (`WingPill.padding`): `Spacing.md` (10 scaled) — unchanged; the height bump plus radius adjust fixes "cramped" without widening.
- Internal item spacing (`WingPill.spacing`): `Spacing.sm` (6 scaled) — unchanged.
- Row spacing between pills: `Sizing.pxFor(7, name)` (up from 6).

**Wing row inner right-padding:** `Spacing.lg` (unchanged).

**Separator rule (between pill groups in the right wing).**
Current: `Rectangle width: Shape.borderThin, height: Sizing.px(12), color: Colors.border, opacity: 0.6`. That's a 1-px hairline — effectively invisible at 1.5× and 1.6× after rounding.
New: `Sizing.pxFor(1.5, name)` wide, `Sizing.pxFor(14, name)` tall, color `Colors.separator` (new, §11), opacity `Effects.opacitySubtle`. Reads as a deliberate tick, not a ghost.

**Battery glyph.**
- Body: `Sizing.pxFor(20, name)` × `Sizing.pxFor(10, name)` (up from 18×9). Current 18 at 1.5× on 4K = 27 px which is fine for presence but the 9 px height only leaves 7 px for the fill — new 10 px leaves 8, which is a full 1-px stop bigger across the whole ladder and reads crisper.
- Border radius: `Sizing.pxFor(2, name)` (unchanged semantically, scales up).
- Fill inset: `Sizing.pxFor(1, name)` per side (unchanged).
- Nub: `Sizing.pxFor(1.5, name)` × `Sizing.pxFor(3, name)` (unchanged).

**Per-screen scale defaults.** Added to `scripts/07-panel.sh` as `Environment=` lines in the systemd unit (orchestrator does this; design just names them):

| Env var | Value | Reasoning |
|---------|-------|-----------|
| `ARCHE_SHELL_LAYOUT_SCALE_eDP_1`     | `1.00` | 16" 2560×1600 at Hyprland scale 1.6 → logical ≈ 1600×1000. At 16" that's ~130 effective logical dpi; 1.0 keeps the notch proportional to the screen. Current global `1.0` is already used on this panel. |
| `ARCHE_SHELL_FONT_SCALE_eDP_1`       | `1.05` | Laptop viewing distance ≈ 55 cm; the 5% font bump pushes `fontMicro` from 10→11 and `fontCaption` from 12→13 after rounding, which is the bare minimum step that fixes the "pixelated/thin" read without enlarging chrome. |
| `ARCHE_SHELL_LAYOUT_SCALE_HDMI_A_1`  | `1.10` | 27" 3840×2160 at Hyprland scale 1.5 → logical 2560×1440 at ~107 effective dpi. The 10% chrome bump on the external fights the "dull at viewing distance" (~80 cm) complaint — pills and tiles get visibly heavier without crossing into "too big". |
| `ARCHE_SHELL_FONT_SCALE_HDMI_A_1`    | `1.10` | Matching 10% font lift keeps the text:chrome ratio identical to laptop post-bump. |

The name-normalization rule: dashes → underscores in env-var suffix (so `HDMI-A-1` → `HDMI_A_1`, `eDP-1` → `eDP_1`). Case-sensitive to match Hyprland's monitor names verbatim.

Math behind the defaults: we compare effective pixel densities after Hyprland scale, measured in "logical px per physical mm" at the panel's typical viewing distance. Laptop ≈ 0.77 logical-px/mm @ 55 cm; external ≈ 0.72 logical-px/mm @ 80 cm. The densities are close but the ratio of logical-px to *angular* size (what the eye cares about) puts the external at ~65% of the laptop's visual weight per pixel — the 10% layout+font bump closes the perceived gap without overshooting.

## 6. Typography hierarchy

**Clock placement — decision: stays in ControlCenter header.**
The Island's idle state already owns center-of-bar clock/date display (see `Ui.qml` state machine: `idle` state renders clock+date). Bringing a second clock to the bar duplicates a datum that already has a home. The ControlCenter header clock remains the "commit to a moment in time" place — click the notch → expand → clock. Non-scope: changing this.

**Workspace number (inside `BarLeftWing` tile).**
- Family: `Typography.fontMono` (MesloLGS Nerd Font Mono) — unchanged.
- Size: `Typography.fontCaption` (12) — *up from* `fontMicro` (10). Tiles at 20 px host a 12 px digit comfortably; 10 px reads anemic.
- Weight: `Typography.weightDemiBold` for active tile, `Typography.weightMedium` for occupied, `Typography.weightNormal` for empty. (Today every tile is Medium.) The DemiBold on active is the "chiselled" feel.
- Color:
  - Active: `Colors.bgAlt` on amber fill — unchanged.
  - Occupied: `Colors.fg` — unchanged.
  - Empty: `Colors.fgDim` — unchanged.
  - Urgent: `Colors.critical` — unchanged.

**Arch glyph.** `Typography.fontLabel` (15) in `Colors.accentAlt` — unchanged, but the glyph box goes from 14 → 16 (§5) so the 15 px glyph no longer clips.

**Wing pill glyphs.** `Typography.fontLabel` (15, up from `fontCaption` 12). Rationale: the pills are interactive targets; a 12 px Nerd Font glyph at 1.5× renders at ~18 physical px, which is below the "instant recognition at glance" threshold for the user's viewing distances. 15 → ~22 physical px crosses that threshold and matches the "status-glyph size" call-out in the user complaints.

**Wing pill numeric labels** (notif count, volume %, battery %). `Typography.fontCaption` (12, up from `fontMicro` 10). `tnum` feature stays on. Weight stays Normal to avoid competing with the glyph for emphasis.

**Recording time label.** `Typography.fontCaption` (12, up from `fontMicro` 10). `Colors.critical`, `tnum` on.

**Clock `·` separator** (in ControlCenter header — not the bar, but called out as a complaint).
Decision: replace the `·` 3×3 dot with a `Typography.fontCaption` middot `•` (U+2022, not `·` U+00B7) rendered in `Colors.fgDim` at `Effects.opacityMuted`, with `Spacing.sm` flanking it. At both DPIs the U+2022 middot is a solid filled disc that rides the typographic baseline — it reads as an intentional separator rather than a speck. Rationale for spacing-backed glyph instead of a vertical rule: the rest of the header is horizontal text flow, a vertical tick would jar.

## 7. Color & depth

**Adaptive surface — two distinct resting colors, linearly blended by `opacityScale`.**

- Translucent state (`opacityScale = 0`): fill = `Colors.surfaceTranslucent` (new, §11) — proposed as `Qt.rgba(0x1d/255, 0x20/255, 0x29/255, 0.78)`, i.e. `Colors.bgSurface` at 78% alpha. Reads with a subtle wash of the wallpaper through, without turning into a "floating frosted card". At 78% the warm-charcoal dominates and the amber accent stays high-contrast.
- Opaque state (`opacityScale = 1`): fill = `Colors.surfaceOpaque` (new, §11) — proposed as `#20232c`, a single step brighter than `Colors.bgSurface` (`#1d2029`). The half-step brighter surface signals "I'm present now, I own this strip" when the user's content has gone full-bleed.

The wing's `color` binds through a JS expression using `Qt.tint` or, simpler, two `Rectangle` layers stacked with opacities driven by `opacityScale` and `1 - opacityScale`. **Pick the two-layer form** — single `Behavior on color` with a `ColorAnimation` can't blend through custom stops, and we want one driver per §10. Two stacked `Rectangle`s both follow the same corner-radius contract (§5 rounding stays identical) so the silhouette is stable.

**Border on the wing.** `Colors.border` at `Shape.borderThin` — unchanged. Becomes more visible in translucent state (good, it defines the edge) and recedes under the opaque state (also good, the fill step does the work).

**Shadow under wing.**
Current: none.
Proposed: new `Effects.shadowBar*` tokens (§11). `MultiEffect` or `DropShadow` with `blurRadius: Effects.shadowBarBlur` (`Sizing.pxFor(14, name)`), `verticalOffset: Effects.shadowBarY` (`Sizing.pxFor(3, name)`), `opacity: Effects.shadowBarOpacity` (`0.45`) — slightly higher than the existing card shadow because the bar sits against variable wallpapers, not a known card ground. Shadow color: `Colors.crust` (new, §11, `#0a0b10`) so it reads warm-black against the Ember palette rather than default pure-black. Shadow is constant across opacity states — it anchors the wing to the screen top edge on both wallpapers and fullscreen apps.

**Workspace tile borders and fills.**
- Empty: fill `transparent`, border `Colors.border` `Shape.borderThin`. Unchanged.
- Hover (not active): fill `Colors.tileBg`, border `0`. Unchanged.
- Occupied (not active, not hover): fill `transparent`, border `Colors.workspaceOccupied` (new, §11, proposed `#3a3e4c` — half-step between `border` and `tileBg`, slightly warmer). The occupancy dot (top-right) stays `Colors.accent`.
- Active: fill `Colors.accent`, border `0`. Unchanged.

**Wing pill state colors.**
- Resting: fill `Colors.pillBg` (`#1d2029`), border `Colors.border`. Unchanged from current `tileBg`? No — current uses `Colors.tileBg`/`tileBgActive`. Change to `Colors.pillBg` / `Colors.pillBgHover` (new, §11, proposed `#262a35`). Rationale: bar pills are not toggle tiles (those are in the drawer); giving them their own role decouples the drawer's hover token from the bar's hover token so drawer polish won't shift the bar.
- Hover: fill `Colors.pillBgHover`, border `Colors.border`. Driven by `MouseArea.containsMouse`.

**Battery fill color rules** (unchanged): `Colors.critical` when pct < 0.15 and not charging, `Colors.success` when charging, `Colors.fg` otherwise.

**StatusOn dot** on wifi/bluetooth pills: `Colors.success` when on, `Colors.fgDim` when off — unchanged.

## 8. Motion envelope

Three animated transitions; one driver each.

**Adaptive opacity crossfade.**
- Driver: `opacityScale` (real, 0..1).
- Behavior: `Anim { type: "standard" }` → 200 ms, `Motion.standard` curve (cubic, no overshoot). Fast enough that switching a window to fullscreen doesn't leave the bar "catching up"; slow enough to feel intentional rather than snappy.
- Rejected: `type: "spatial"` (500 ms) — too slow for a color-class change; `type: "fast"` (120 ms) — reads as a flicker and eliminates the "taking its time" quality we want.
- Properties this drives (fanned out from the one driver): `translucentLayer.opacity = 1 - opacityScale`, `opaqueLayer.opacity = opacityScale`. No other property (not size, not border, not shadow) animates on this trigger.

**Workspace tile state change.**
- Color change: existing `Behavior on color { CAnim { type: "fast" } }` — keep. 120 ms with standard curve.
- No new motion added.

**Wing pill hover.**
- Color change: existing `Behavior on color { CAnim { type: "fast" } }` — keep.

**Adaptive opacity startup guard.**
`opacityScale` defaults to `0` (translucent). The `Behavior` only kicks in after first binding evaluation — so the first `hasFullscreen: true` scenario animates from translucent to opaque over 200 ms, which is correct behavior (no flash). If Hyprland.monitors is empty on first paint, `_mon` is `null`, `hasFullscreen` is `false`, `opacityScale` stays 0. Good.

Tokens referenced: `Motion.durationStd`, `Motion.standard`, `Motion.durationFast` (all exist). No new Motion tokens required.

## 9. Interaction & focus

- Bar wing surfaces themselves: no interactive handlers. Wings are display; interactivity lives on pills and tiles. Keyboard focus remains `WlrKeyboardFocus.None`.
- Workspace tiles: existing `MouseArea` with `-Sizing.pxFor(3, name)` extended hit margin — unchanged, inclusive of the 20-px tile bump.
- Wing pills: existing `WingPill` click + scroll — unchanged. Pills open popovers via `Ui.togglePopover(name)`; popover design is peer-owned.
- No new trigger paths. No new `IpcHandler` targets. All adaptive behavior is reactive to `Hyprland.monitors`.

## 10. Adaptive opacity driver — reactive chain

**Per-screen chain:**

```qml
// Inside each wing PanelWindow (root):
readonly property var _mon: {
    const ms = Hyprland.monitors?.values ?? []
    const n  = root.screen?.name ?? ""
    return ms.find(m => m.name === n) ?? null
}
readonly property bool hasFullscreen:
    !!(_mon && _mon.activeWorkspace && _mon.activeWorkspace.hasFullscreen)

property real opacityScale: hasFullscreen ? 1 : 0
Behavior on opacityScale { Anim { type: "standard" } }

// Two stacked Rectangles inside wingBody:
Rectangle { id: translucentLayer
    anchors.fill: parent; color: Colors.surfaceTranslucent
    /* same radii as wingBody */
    opacity: 1 - root.opacityScale
}
Rectangle { id: opaqueLayer
    anchors.fill: parent; color: Colors.surfaceOpaque
    /* same radii as wingBody */
    opacity: root.opacityScale
}
```

**Values the driver takes:** discrete `0` (translucent) or `1` (opaque) as source, continuous in `[0, 1]` during the Behavior-interpolated crossfade.

**Properties the Behaviors drive:** the two layer opacities only. One numeric source (`opacityScale`), two derived bindings (`1 - opacityScale` and `opacityScale`) on the same property type — no racing Behaviors (trap #9).

**Edge cases:**
- `Hyprland.monitors.values` empty at startup → `_mon` is `null` → `hasFullscreen` is `false` → translucent. Correct.
- `root.screen` is `null` transiently during screen add/remove → `n === ""` → `find()` returns `undefined` → fallback `null` → translucent.
- No `activeWorkspace` (monitor exists but no workspace assigned yet) → optional chaining short-circuits → `hasFullscreen` false → translucent.
- User toggles fullscreen on a different monitor → that monitor's wing responds; the other monitor's wing is unaffected. This is the per-screen correctness we chose `_mon = find(by name)` for, rather than `Hyprland.focusedMonitor`.
- User switches workspace on this monitor → `activeWorkspace` changes → `hasFullscreen` re-evaluates → if the target workspace has fullscreen, opaque; else translucent. Desired.
- Shell startup flicker protection: `opacityScale` default = `0` (initializer is evaluated against the initial binding value — if Hyprland is already up with fullscreen on, we animate 0→1 on first paint, never 1→0).

## 11. New theme roles needed

Orchestrator adds these before coding begins. All modifications go in `theme/*.qml` per §2 of theming.md.

**`theme/Colors.qml`:**
```
readonly property color surfaceOpaque:      "#20232c"   // bar when fullscreen under it
readonly property color surfaceTranslucent: Qt.rgba(0x1d/255, 0x20/255, 0x29/255, 0.78)
readonly property color pillBg:       "#1d2029"   // rename semantic, already the hex we have; explicit role for bar pills (distinct from tileBg role)
readonly property color pillBgHover:  "#262a35"   // bar pill hover — half-step above pillBg
readonly property color workspaceOccupied: "#3a3e4c"  // border for occupied-but-not-active tile
readonly property color separator:    "#3a3e4c"   // vertical rule between pill groups (alias of workspaceOccupied OK if we want one token; keep two names for future divergence)
readonly property color crust:        "#0a0b10"   // warm-black for shadow color
```
Note: `pillBg` already exists with the same hex — keep it; the rename is purely role-docstring. `tileBg`/`tileBgActive` stay as-is (drawer toggle tiles).

**`theme/Effects.qml`:**
```
readonly property int  shadowBarBlur:    Sizing.px(14)
readonly property int  shadowBarY:       Sizing.px(3)
readonly property real shadowBarOpacity: 0.45
// existing surfaceAlpha stays; adaptive wings use Colors.surfaceTranslucent's baked alpha, not this
readonly property real surfaceAlphaOpaque:      1.0  // for completeness, referenced by brief
readonly property real surfaceAlphaTranslucent: 0.78 // matches Colors.surfaceTranslucent
```

**`theme/Shape.qml`:**
```
readonly property int radiusPillWing: Sizing.px(9)   // bar pill — was inline Sizing.px(8)
```

**`theme/Sizing.qml` — new functions + env plumbing:**
```
function _envScale(varName: string): real {
    const raw = parseFloat(Quickshell.env(varName) || "")
    if (isNaN(raw) || raw <= 0) return NaN
    return Math.max(0.75, Math.min(2.0, raw))
}
function _perScreenLayoutScale(name: string): real {
    if (!name) return layoutScale
    const key = "ARCHE_SHELL_LAYOUT_SCALE_" + name.replace(/-/g, "_")
    const v = _envScale(key)
    return isNaN(v) ? layoutScale : v
}
function _perScreenFontScale(name: string): real {
    if (!name) return fontScale
    const key = "ARCHE_SHELL_FONT_SCALE_" + name.replace(/-/g, "_")
    const v = _envScale(key)
    return isNaN(v) ? fontScale : v
}
function pxFor(base: real, screenName: string): int {
    return Math.round(base * _perScreenLayoutScale(screenName))
}
function fpxFor(base: real, screenName: string): int {
    return Math.round(base * _perScreenFontScale(screenName))
}
```
Global `px`, `fpx`, `layoutScale`, `fontScale` remain — components that aren't screen-aware (drawers shown on focused monitor only, OSDs) keep using them.

**`theme/Motion.qml`:** no changes needed — `durationStd` + `standard` curve cover the adaptive crossfade.

**New `Environment=` entries in `scripts/07-panel.sh`** (orchestrator land):
```
Environment=ARCHE_SHELL_LAYOUT_SCALE_eDP_1=1.00
Environment=ARCHE_SHELL_FONT_SCALE_eDP_1=1.05
Environment=ARCHE_SHELL_LAYOUT_SCALE_HDMI_A_1=1.10
Environment=ARCHE_SHELL_FONT_SCALE_HDMI_A_1=1.10
```

## Anti-patterns avoided

- **Trap #6** — namespaces stay as string literals in each wing, not dynamic bindings.
- **Trap #9** — one `opacityScale` driver per wing feeds two derived opacity bindings; no two Behaviors on correlated properties.
- **Trap #11** — all three bar surfaces are already wrapped in `Variants { model: Quickshell.screens }` in `shell.qml`; brief preserves that.
- **Anti-pattern: compositor blur for depth** — not proposed. Depth = shadow + two-layer surface contrast.
- **Anti-pattern: hardcoded hexes** — every color named; new hexes proposed only through §11 tokens.
- **Anti-pattern: polling what's reactive** — `Hyprland.monitors.values[i].activeWorkspace.hasFullscreen` is reactive; no `Timer` needed.
- **Anti-pattern: per-toplevel `lastIpcObject` reach** — the user's recon explicitly called this out; brief uses the per-monitor workspace property instead.
- **Trap #1** — wing silhouette is a single `Rectangle` with four corner radii; the two opacity layers share that Rectangle as parent so corners can't desync.

## Visual verification checklist

After implementation, confirm each with the commands below.

1. **Journal clean.** `journalctl --user -u quickshell.service -f` — no QML errors during startup or first fullscreen toggle.
2. **Translucent at rest (both screens).** `grim -o eDP-1 /tmp/verify-laptop-rest.png` and `grim -o HDMI-A-1 /tmp/verify-ext-rest.png` with a normal tiled desktop (no fullscreen). Pills, tiles, and wings should show a subtle wash of the wallpaper through the surface.
3. **Opaque on fullscreen (laptop only).** On eDP-1, fullscreen a terminal: `hyprctl dispatch fullscreen 1`. Within ~240 ms the eDP-1 wings firm up (visibly brighter fill, wallpaper no longer bleeding through). External wings stay translucent. `grim -o eDP-1 /tmp/verify-laptop-fs.png` — compare to rest shot; fill should be `#20232c` not `#1d2029`.
4. **Per-screen independence.** `hyprctl dispatch focusmonitor HDMI-A-1 ; hyprctl dispatch fullscreen 1`. Now external wings opaque, laptop still translucent (assuming laptop window toggled back out). No cross-wiring.
5. **Workspace switch resets opacity.** With fullscreen active on workspace 1, `hyprctl dispatch workspace 2` (to an empty workspace on the same monitor). Wings fade back to translucent within 200 ms.
6. **Per-screen scale defaults applied.** `qs ipc show` — no new targets, nothing breaks. Inspect a pill at native resolution via screenshot: laptop pill height should render ~24 × 1.6 × 1.0 = ~38 physical px; external pill ~24 × 1.5 × 1.10 = ~40 physical px. Crisp at both.
7. **Env-var override works.** `ARCHE_SHELL_LAYOUT_SCALE_eDP_1=1.25 systemctl --user restart quickshell.service` — laptop pills get visibly chunkier; external untouched.
8. **No flash on reload.** Save a bar file to trigger hot-reload. Wings should re-appear translucent (default) and only animate to opaque if fullscreen is currently active — never flash opaque-then-translucent.
9. **Workspace tile legibility.** Active tile on laptop: the digit should be unambiguously readable in a 1:1 `grim` capture. Compare to pre-change `/tmp/arche-panel-redesign/laptop.png` — should be visibly less "thin".
10. **Separator presence.** In the right-wing crop, the tick between notifications and wifi pills should be a deliberate vertical rule, not a hairline — visible in both grim crops without zooming.

---

## Summary

The brief commits to: per-wing `opacityScale` driver reading `Hyprland.monitors[…].activeWorkspace.hasFullscreen`, two stacked `Rectangle` layers with complementary opacities (`surfaceTranslucent` ↔ `surfaceOpaque`), one 200 ms `standard`-curve Behavior per driver. Pills grow to height 24 px, radius 9 px, with a dedicated `pillBg`/`pillBgHover` role pair; workspace tiles go to 20 px with a `fontCaption` DemiBold digit and a new `workspaceOccupied` border; separators become 1.5 × 14 px rules using a new `Colors.separator`; the clock stays in the ControlCenter header (no bar duplication); a shared warm-black bar shadow (new `Effects.shadowBar*`) anchors wings to the top edge. Per-screen scaling lands via `Sizing.pxFor`/`fpxFor` + `ARCHE_SHELL_LAYOUT_SCALE_<screenname>` / `_FONT_SCALE_<screenname>` env vars with defaults 1.00/1.05 for eDP-1 and 1.10/1.10 for HDMI-A-1. The Island is untouched. All numbers routed through tokens; 12 new theme roles enumerated in §11 for the orchestrator to add before coding begins.
