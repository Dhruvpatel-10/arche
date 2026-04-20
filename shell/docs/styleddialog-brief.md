# Design Brief: StyledDialog — Unified Dialog Primitive

## 1. Intent

Opening a dialog from anywhere in the arche shell should feel like the *same* surface arriving. Same scrim darkening the focused monitor, same amber-bordered charcoal card landing with the same settling motion, same keyboard contract (Enter commits, Esc dismisses, outside-click dismisses, hover-out does nothing), same corner radius, same shadow weight. The user should never notice the boundary between LauncherDialog, ClipboardPicker, PowerMenuDialog and their future confirm step — not because they look identical (they don't, a confirm is smaller than a picker) but because they speak one vocabulary. Today each file re-implements that vocabulary with slightly different words: `ControlCenter` uses the `offsetScale` spatial driver, `PickerDialog` uses twin `Behavior on opacity` + `Translate` races, each file reaches into a different mix of `Theme.*` legacy tokens. The work is to collapse this into one component — `StyledDialog` — that every centered modal surface consumes, and to extend that vocabulary with the first *confirm* variant so destructive actions get a two-step contract without inventing a new surface class.

## 2. Scope / Non-Scope

**In scope:**
- New primitive `components/StyledDialog.qml` (extends `StyledWindow`).
- Refactor `components/PickerDialog.qml` to compose `StyledDialog` (role = Picker) instead of `StyledWindow` directly. Migrates its color/typography/motion tokens off `Theme.*` onto `Colors.*` / `Typography.*` / `Motion.*`.
- `components/PowerMenuDialog.qml` gains a *confirm* step for destructive actions (Shutdown, Reboot). The existing picker UI stays; on Enter for a destructive action it opens a secondary `StyledDialog { role: Confirm }` instead of calling `PowerMenu.run` immediately.
- `components/LauncherDialog.qml`, `components/ClipboardPicker.qml`: inherit the migration via `PickerDialog`'s switch. No API change at the dialog-consumer layer — their properties remain identical.
- `components/CalendarPanel.qml`: **deferred**, with reason below (§9).
- Minor token hygiene in `components/ControlCenter.qml` — migrate `Theme.card / border / padLg / fontSans / fontSize / radiusLg` → modular tokens. The reference behavior (per-monitor scrim, `offsetScale` driver, cursor-off-monitor `Connections`) stays unchanged; it is the reference, and the coder should only retune bindings to the new tokens.

**Non-scope:**
- `components/ControlCenter.qml` layout / interactions — it is the *reference*, not a migration target beyond token hygiene.
- Any `WingPopover.qml` work. Wing popovers are anchored peripheral drawers, not centered dialogs. Different surface class. The peer designer owns that axis via the panel refresh.
- Adaptive / translucent bar opacity — peer owns this.
- Any `GaussianBlur` or backdrop effect. Prohibited per `Effects.qml` and the Ember aesthetic rule.
- `CalendarPanel` is a top-anchored, center-horizontal drawer (not a centered modal). It is more structurally like a drawer than a dialog. Forcing it into `StyledDialog` would either bloat the primitive with anchor modes or break its "slides down from the clock" affordance. Defer to a follow-up that may produce `StyledDrawer` (sibling primitive) rather than widen `StyledDialog`.

## 3. Primitive API — `components/StyledDialog.qml`

`StyledDialog` **extends** `StyledWindow` (the existing `PanelWindow` wrapper that gives every surface a unique Hyprland namespace). It adds the scrim/card/focus-transfer/motion envelope that today is re-implemented per-file. Rationale: `StyledWindow` already owns namespace hygiene (trap #6) and three dialog roles all want centered cards on per-monitor scrims — so extension beats a sibling primitive.

### Public API

```qml
StyledDialog {
    id: dlg
    name: "powermenu-confirm"                // → "arche-powermenu-confirm"
    role: StyledDialog.Confirm               // Picker | Confirm | (Drawer reserved)
    open: PowerMenu.confirmOpen              // caller-owned state flag
    maxWidth:  Sizing.px(380)
    maxHeight: Sizing.px(220)
    dangerDefault: false                     // Confirm: focus danger on open?
    default property alias content: body.data
    signal dismissed(string reason)          // "outside" | "esc" | "commit" | "cancel" | "action"
}
```

### Property inventory

| Property | Type | Default | Purpose |
|---|---|---|---|
| `role` | enum `Picker` / `Confirm` / (`Drawer` reserved) | `Picker` | Chooses keyboard-focus mode, card max dimensions, hint-footer visibility. |
| `name` | string | `""` (inherited) | Required unique string literal — flows into `WlrLayershell.namespace` via `StyledWindow`. Trap #6 + #7. |
| `open` | bool | `false` | Caller-owned state flag. Coder must not mutate; only `dismissed(reason)` notifies. |
| `maxWidth` / `maxHeight` | int | role-defaulted | Card ceiling. Actual dims = `Math.min(max, screen - margin)`. |
| `dangerDefault` | bool | `false` | `Confirm` only. When `false`, Cancel takes initial keyboard focus — the user must explicitly Tab to the danger action. This is the "danger button must not be default-focused" contract. |
| `content` (default) | list | — | Child items assigned here render inside the card's padding. Consumer supplies `PickerSearchBar` + `PickerList` + hints (Picker), or a title/body/buttons row (Confirm). |

### Signal contract

One signal: `dismissed(reason: string)`. Every closure path emits exactly once. Values:

- `"outside"` — scrim click (no action).
- `"esc"` — Escape on the focused input (no action).
- `"commit"` — Enter on a Picker (consumer accepts the selected item).
- `"cancel"` — Cancel button on a Confirm (no action).
- `"action"` — Danger button on a Confirm (consumer runs the destructive command).
- `"monitor-left"` — focused monitor changed away. Semantically equal to `"outside"`; named separately so a consumer can opt to *not* dismiss (e.g., a future sticky dialog) without regressing the default.

Consumer wires exactly one handler:

```qml
onDismissed: (reason) => {
    if (reason === "commit") Launcher.launch(picker.selected)
    else if (reason === "action") PowerMenu.run(pendingAction)
    Launcher.hide()                          // every path closes the caller
}
```

No separate `onAccepted` / `onRejected` / `onCancelled` signals — callers shouldn't have to re-derive the reason from which signal fired. The single channel also makes dismissal-path auditing (`grep onDismissed`) trivial.

### Why not three separate components?

Because then `Colors.dialogScrim` / `Shape.radiusDialog` / `Motion.easeDialog` would have to be wired identically in three files, and drift is guaranteed. One primitive + role enum is the contract surface; variants are data.

## 4. Surface Composition

Identical skeleton for Picker and Confirm; role only affects default dimensions and which keyboard-focus mode the layershell requests:

- Root = `StyledWindow` (so namespace is construction-only and unique).
- `anchors { top: true; bottom: true; left: true; right: true }` — full monitor minus the bar, via `ExclusionMode.Ignore`. One surface, one screen.
- `color: "transparent"`, `exclusiveZone: 0`, `WlrLayershell.layer: WlrLayer.Overlay`.
- Child 1: scrim `Rectangle`, `anchors.fill: parent`, `color: Colors.dialogScrim`, `opacity: 1 - offsetScale` so it fades with the card.
- Child 2: scrim `MouseArea`, `anchors.fill: parent`, `onClicked: root.dismissed("outside")`.
- Child 3: card `Rectangle`, `anchors.centerIn: parent`, `width: Math.min(maxWidth, parent.width - Spacing.dialogInset * 2)`, `height: Math.min(maxHeight, parent.height - Spacing.dialogInset * 2)`, `radius: Shape.radiusDialog`, `color: Colors.dialogSurface`, `border { color: Colors.dialogBorder; width: Shape.borderThin }`. Drop shadow via `Effects.shadowDialog`.
- Card swallows clicks (`MouseArea { anchors.fill: parent }`) — the current pattern.
- `Loader { id: contentLoader }` anchored inside the card with `Spacing.dialogPad`; default content alias routes to a child `Item` whose children the caller declares.
- `Connections { target: Hyprland; onFocusedMonitorChanged: ... }` dismisses via `"monitor-left"` when the focused monitor no longer matches `root.screen`.

The card uses `onVisibleChanged` to transfer focus: on open, `Qt.callLater` on a function the role overrides — Picker transfers to the first `TextInput` descendant (`PickerSearchBar.input`); Confirm transfers to Cancel (default) or Danger (if `dangerDefault`). Never both in the same delay — one `callLater` → one target.

## 5. Dismissal Matrix

| Role | Outside click | Esc | Enter | Del | Cancel btn | Danger btn | Focused monitor changes | Hover-out anywhere |
|---|---|---|---|---|---|---|---|---|
| Picker  | `"outside"` | `"esc"` | `"commit"` (via search bar) | forwarded to consumer as today (`onRemoved`) | — | — | `"monitor-left"` | **no dismissal** |
| Confirm | `"outside"` | `"esc"` | fires focused button's action (`"cancel"` by default, `"action"` iff danger focused) | — | `"cancel"` | `"action"` | `"monitor-left"` | **no dismissal** |

"Hover-out anywhere" is explicitly enumerated to codify the fix for the user's current complaint. There is no `onExited` handler on the scrim or card; nothing watches pointer-leave. Verified against `PickerDialog.qml` — today's behavior is already correct on this axis; this matrix locks it in so a future rewrite can't regress.

Consumers translate the reason string into domain semantics. There is no `dismissed()` no-arg overload — the one-signal contract is sacred.

## 6. Animation Envelope — one numeric driver

```qml
readonly property bool shouldBeActive: open
property real offsetScale: shouldBeActive ? 0 : 1
visible: shouldBeActive || offsetScale < 1
Behavior on offsetScale { Anim { type: "dialog" } }
```

`Anim.type: "dialog"` is a **new preset** added to `components/Anim.qml` — duration `Motion.durationDialog`, easing `Motion.easeDialog`. One driver, three derived visuals:

- `scrim.opacity: (1 - offsetScale)` — scrim fades linearly.
- `card.opacity: (1 - offsetScale)` — card fades.
- `card transform Translate { y: offsetScale * Sizing.px(8) }` — card drifts 8px down while offsetScale → 1 (closing) or 0 (opening), so the enter motion is "settle from above." Scale is intentionally **not** driven — scale animations on dark cards against dark scrims read as jank at our radius.

Enter and exit share one envelope for the Picker (symmetric feels crisp). For the Confirm, the orchestrator may opt the coder into a slightly faster exit by picking `durationFast` manually on close — but the default is symmetric and sufficient. Do not introduce two behaviors racing (trap #9).

Motion tokens to introduce:

- `Motion.durationDialog` — 200 ms (`durationStd`; proposing an alias rather than a new number).
- `Motion.easeDialog` — `Motion.standardDecel` on open, `Motion.standardAccel` on close. Because `Behavior` reads one curve, alias to `Motion.standard` and accept slight asymmetry. If the coder finds the symmetric version visibly wrong, they can split via `SequentialAnimation` — but start with `Motion.standard` as a scalar token, same pattern as `CalendarPanel` uses for month-swap.

Consumers never write their own Behavior. `StyledDialog` owns this; role = Picker/Confirm inherits the same envelope.

## 7. Scrim & Focus

**Scrim color:** new role `Colors.dialogScrim`. Propose `Qt.rgba(0, 0, 0, 0.45)` — deep enough to disambiguate the dialog from the bar's rising opacity (peer's axis) without being so black the ember accent on the card edge loses warmth.

**Layer:** always `WlrLayer.Overlay` — must sit above all normal windows and above the bar so the scrim covers the bar fully.

**Exclusion:** `WlrLayershell.exclusionMode: ExclusionMode.Ignore`. Confirmed already present on `PickerDialog`. Required so the scrim covers the full monitor height, not just below the bar.

**Keyboard focus by role:**

| Role | `WlrKeyboardFocus` | Initial target | Tab order |
|---|---|---|---|
| Picker | `Exclusive` | first `TextInput` inside `content` | search input is the only focusable; Tab no-ops |
| Confirm | `Exclusive` | Cancel button (unless `dangerDefault`) | Cancel ⇄ Danger |

`Exclusive` on the Confirm is deliberate — if it were `OnDemand`, a user could keep typing into their current application while the confirm is open, Enter would land in that application, and the danger action would feel disconnected. Exclusive grabs the keyboard so Esc and Enter cannot leak.

Tab order on Confirm: Cancel → Danger → Cancel. Shift+Tab reverses. Arrow Left/Right mirrors Tab. Enter commits focused. Esc is always `"esc"`.

## 8. Typography & Surface

### Card

- Background: `Colors.dialogSurface` — new role. Proposed hex `#181b23` (same as `Colors.card` today). A distinct role because the peer designer owns `Colors.surfaceOpaque` for the bar and they may flex — the dialog surface must stay opaque and warm-neutral regardless.
- Border: `Colors.dialogBorder` — new role. Proposed `#282c38` (`Colors.border`). Distinct role again so dialogs don't inherit if someone tightens the bar border.
- Radius: `Shape.radiusDialog` — new alias resolving to `Shape.radiusLarge` (25px scaled). Deliberately larger than picker's current `Shape.radius` (17) — dialogs deserve a more "modal" corner. Confirmed against arche's radius ladder (Shape.qml comments).
- Inner padding: `Spacing.dialogPad` — new alias resolving to `Spacing.lg` (16px scaled).
- Content gap: `Spacing.dialogContentGap` — new alias resolving to `Spacing.md` (10px scaled). Used between title/body/action rows in Confirm.
- Shadow: `Effects.shadowDialog` — new role set, one step above the bar shadow. Proposed: `shadowDialogBlur = Sizing.px(32)`, `shadowDialogYOffset = Sizing.px(8)`, `shadowDialogOpacity = 0.40`. Implemented via `MultiEffect` as an attached rectangle-sibling, not a child of the card (avoids self-clipping).

### Picker typography (already established, re-stated for migration)

- Prompt label (accent): `Typography.fontSans`, `Typography.fontCaption`, `Typography.weightDemiBold`, `Colors.accent`.
- Search input: `Typography.fontSans`, `Typography.fontTitle`, `Colors.fg`.
- Placeholder: same font, `Colors.fgDim`.
- Hint footer key: `Typography.fontMono`, `Typography.fontCaption`, `Colors.fgMuted`.
- Hint footer value: `Typography.fontSans`, `Typography.fontCaption`, `Colors.fgDim`.

All current `Theme.fontMono/Sans/fontCaption/fontTitle` references in `PickerSearchBar.qml` and `PickerDialog.qml` migrate to the above modular tokens.

### Confirm typography

- Title: `Typography.fontSans`, `Typography.fontLabel`, `Typography.weightDemiBold`, `Colors.fg`. E.g. "Shut down now?"
- Body: `Typography.fontSans`, `Typography.fontBody`, `Colors.fgMuted`. Optional — skip for unambiguous actions. E.g. "Unsaved work will be lost."
- Action label: `Typography.fontSans`, `Typography.fontBody`, `Typography.weightMedium`. Cancel uses `Colors.fg`; Danger uses `Colors.critical`.

### Danger button

Outlined, not filled. Rationale: a filled red rectangle at radius 12 next to a charcoal card reads as an alert banner, which this isn't — it's a confirmation. Outlined feels deliberate.

- Background at rest: `"transparent"`.
- Background on hover: `Colors.dangerBg` — new role, `Qt.rgba(Colors.critical.r, Colors.critical.g, Colors.critical.b, 0.11)` (matches `PickerItemBase`'s selected tint recipe for consistency).
- Border: `Colors.dangerBorder` — new role, proposed `Colors.critical` at full opacity (same `#c45c5c`).
- Text color: `Colors.critical`.
- Radius: `Shape.radiusSm` (12).
- Height: `Sizing.px(36)`.
- Focus ring: 1px `Colors.critical` outer stroke at 50% opacity.

Cancel button uses the same geometry, `Colors.border` border, `Colors.fg` text — a neutral counterpart.

## 9. Per-surface application

### 9a. PowerMenu

Today `PowerMenuDialog.qml` shows a picker list of 5 actions; Enter on any action immediately fires `PowerMenu.run(item)`. Change:

1. `PowerMenu.qml` gains a `confirmOpen` bool flag and a `pendingAction` property.
2. `PowerMenu.actions` entries gain a `danger: true/false` field:
   - `lock`, `sleep`, `logout` → `danger: false` (run immediately).
   - `reboot`, `shutdown` → `danger: true` (requires confirm step).
3. `PowerMenu.run(action)` checks `action.danger`: if true, sets `pendingAction = action; confirmOpen = true` and does **not** close the picker; if false, closes picker and runs action as today.
4. New file `components/PowerMenuConfirm.qml` — a `StyledDialog { role: Confirm }` consumer. Content:
   - Title: `"<label>?"` — i.e. "Shutdown?" or "Reboot?".
   - Body: `pendingAction.id === "shutdown" ? "Your session will end and the system will power off." : "Your session will end and the system will restart."`
   - Cancel + Danger buttons. Danger label mirrors action label ("Shutdown" / "Reboot").
   - `dangerDefault: false` — Cancel focused by default.
   - `onDismissed(reason)`:
     - `"action"` → `PowerMenu._proc.command = pendingAction.cmd; _proc.running = true; hide()` (close both confirm and parent picker).
     - any other reason → just `confirmOpen = false` (picker stays open, returns focus to picker's search).
5. `shell.qml` instantiates `PowerMenuConfirm {}` adjacent to `PowerMenuDialog {}`.

The focus dance: while confirm is open, its `Exclusive` keyboard focus supersedes the picker's. When confirm dismisses to `"cancel"` or `"outside"` or `"esc"`, the picker's `Exclusive` focus re-asserts automatically (Quickshell does this when the overlay surface visibility drops). Verify with the verification checklist.

### 9b. LauncherDialog

No caller-side behavior changes. Migration is internal: `PickerDialog` becomes a thin `StyledDialog { role: Picker }` wrapper. Consumer surface (`pickerName`, `prompt`, `items`, `delegate`, `onAccepted`, `onDismissed`, ...) is unchanged.

Regression checks the coder must verify during migration:
- Hover-out → no dismissal (confirm against §5 matrix).
- Cursor to external monitor → dismiss (`"monitor-left"`).
- Esc → dismiss (`"esc"`).
- Enter while fzf loading → commits current top result (not queued).
- Backspace empties query → `query = ""`, selection snaps to 0.
- Hot-reload during open → survives (StyledWindow already good).

### 9c. ClipboardPicker

Identical migration as LauncherDialog. The right pane (`Preview`) is a `rightPane: Component` slot on `PickerDialog` — this slot survives the migration. Verify image preview still decodes on selection change.

### 9d. CalendarPanel — deferred

Reason: `CalendarPanel` anchors to `parent.top` with `horizontalCenter` alignment — it slides down from the clock in the center island, not from screen center. Giving `StyledDialog` anchor-mode configuration (`anchor: "center" | "topCenter" | "topRight"`) multiplies the geometry branches in the primitive without a second consumer beyond `CalendarPanel`. Cleaner to leave `CalendarPanel` as a direct `StyledWindow` consumer, converge its token references (`Theme.card` → `Colors.card`, `Theme.padLg` → `Spacing.lg`, `Theme.radiusLg` → `Shape.radiusLg`, `Theme.border` → `Colors.border`) as part of the same migration PR, and consider a sibling `StyledDrawer` primitive in a follow-up if a second top-anchored drawer appears.

Token-hygiene migration list for `CalendarPanel.qml`:

```
Theme.card     → Colors.card
Theme.border   → Colors.border
Theme.padLg    → Spacing.lg
Theme.radiusLg → Shape.radiusLg
```

## 10. Conflict with peer designer

The peer designer is introducing adaptive bar opacity via `Colors.surfaceOpaque` / `Colors.surfaceTranslucent` (or similar). Dialogs are categorically different:

- Dialogs are always fully opaque. They are the focal surface; letting the desktop bleed through would defeat the visual hierarchy.
- Dialogs never sit in the bar's coordinate system — they occupy the full monitor.

**Separation contract:**
- `Colors.dialogSurface` — new, dialog-specific, opaque. Not coupled to `Colors.surfaceOpaque`. Even if they start at the same hex, they may diverge later (e.g., if the peer tightens `surfaceOpaque` toward `bgAlt`, dialogs should stay at `card`).
- `Colors.dialogBorder` — same logic. Distinct from any bar border role.
- `Colors.dialogScrim` — unambiguously dialog-only (nothing else uses a scrim at this opacity; wing popovers use their own transparent scrim as pass-through click catchers).
- `Colors.dangerBg` / `Colors.dangerBorder` — dialog-local but reusable if a future toast or control-center confirm wants the same pattern.

Shared with the peer's work (stay in sync):
- `Colors.accent` — the amber brand.
- `Colors.critical` — the base for danger styling. Peer must not shift its hue without coordinating.
- `Motion.standard` / `standardDecel` / `standardAccel` — the easings; they are neutral by design.

## 11. New theme roles to add

Orchestrator adds these to `/opt/arche/shell/theme/*.qml` before the coder starts. The coder uses them as first-class references; if a role is missing the coder must halt and request it rather than inline a hex.

### `theme/Colors.qml`
```qml
readonly property color dialogScrim:  Qt.rgba(0, 0, 0, 0.45)
readonly property color dialogSurface: Colors.card                  // alias for now
readonly property color dialogBorder:  Colors.border                // alias for now
readonly property color dangerBg:      Qt.rgba(critical.r, critical.g, critical.b, 0.11)
readonly property color dangerBorder:  critical
```
(Aliases are fine — the *name* is the contract, so future divergence is a one-file edit.)

### `theme/Shape.qml`
```qml
readonly property int radiusDialog: radiusLarge   // 25px scaled
```

### `theme/Spacing.qml`
```qml
readonly property int dialogPad:        lg    // 16
readonly property int dialogContentGap: md    // 10
readonly property int dialogInset:      xl    // 24 — margin from card to screen edge
```

### `theme/Motion.qml`
```qml
readonly property int  durationDialog: durationStd      // 200
readonly property var  easeDialog:     standard         // the bezier array
```

### `theme/Effects.qml`
```qml
readonly property int  shadowDialogBlur:    Sizing.px(32)
readonly property int  shadowDialogYOffset: Sizing.px(8)
readonly property real shadowDialogOpacity: 0.40
```

### `components/Anim.qml` — new preset
Add a `"dialog"` branch in the `type` switch, routing to `Motion.durationDialog` + `Motion.easeDialog`.

## Wiring delta — what the orchestrator must change (coder does NOT touch these)

- **`Ui.qml`:** no change. PowerMenu's `confirmOpen` / `pendingAction` are owned by `PowerMenu.qml`, not `Ui`. Rationale: they're domain-specific, not cross-component.
- **`Shortcuts.qml`:** no change. The existing `qs ipc call powermenu show|hide|toggle` target stays. Confirm has no IPC surface — it's always driven by the picker.
- **`shell.qml`:** add one line — `PowerMenuConfirm {}` instantiation, after `PowerMenuDialog {}`.
- **`theme/*.qml`:** add the roles enumerated in §11.
- **`theme/qmldir`:** no change (existing singletons are already registered).
- **`components/`:** no `qmldir` in that folder today (verified); new components are imported by path. Coder adds `StyledDialog.qml` + `PowerMenuConfirm.qml` + new `"dialog"` branch in `Anim.qml`.
- **`PowerMenu.qml`:** coder adds `confirmOpen`/`pendingAction` properties and updates `run()` — within the coder's scope since `PowerMenu.qml` is a domain singleton, not a load-bearing shell file.

## Anti-patterns avoided (named)

Mapped to `quickshell-pitfalls`:

- **Trap 2 (coexisting color systems):** migrating PickerDialog/ControlCenter off `Theme.*` onto `Colors.*`/`Typography.*`/`Spacing.*`/`Shape.*` is explicit in scope.
- **Trap 6 & 7 (namespace as binding / default namespace):** `name` is a plain-string alias on `StyledWindow`; every consumer supplies a unique string literal. `PowerMenuConfirm` gets `name: "powermenu-confirm"`.
- **Trap 9 (racing behaviors):** one numeric driver (`offsetScale`) drives opacity + y-translate. No `Behavior on opacity` *and* `Behavior on y` on the same transition. Collapses today's `PickerDialog:265-270` race.
- **Trap 11 (single instance on multi-monitor):** dialogs are explicitly designed as one-per-focused-monitor via `screen:` binding to the current `Hyprland.focusedMonitor`. Still one instance, but it moves to the right monitor on open (current `PickerDialog` pattern lines 68–76); verified correct across eDP-1 + HDMI-A-1.
- **Trap 5 (qmldir registration):** no new `qmldir` needed — `components/` has no qmldir today; imports remain path-based.
- **Blur ban:** scrim is a flat `Rectangle` with alpha. No `MultiEffect` blur. Depth comes from shadow (`Effects.shadowDialog*`) and surface contrast (`dialogSurface` on `dialogScrim`).
- **Theme.controlCenterWidth silent-undefined hazard (reference-only):** noted but out of scope for this brief. Coder may fix opportunistically while migrating ControlCenter tokens — replace `Theme.controlCenterWidth` with `Sizing.px(420)` inlined, or propose a new `Sizing.controlCenterWidth` role. Orchestrator's call.

## Verification checklist — coder runs after build

Exercise every path on both monitors. Use IPC, not mouse sim, per pitfalls-skill visual verification step 3.

**Setup:** `journalctl --user -u quickshell.service -f` in a terminal.

**Picker (Launcher as exemplar):**
```
qs ipc call launcher show       # opens on focused monitor
# cursor on eDP-1:  dialog on eDP-1
# cursor on HDMI-A-1: repeat, verify it opens there
grim -g "$(slurp)"              # screenshot the card — verify 25px radius, 16px pad, dialog shadow
# Type "fire" → Enter → Firefox launches, picker closes
qs ipc call launcher show       # reopen
# Click scrim → closes (no action)
qs ipc call launcher show
# Press Esc → closes
qs ipc call launcher show
# Move cursor to other monitor → closes
qs ipc call launcher show
# Hover out over bar, back in, out over bottom edge → stays open (hover-out has no dismissal)
```

**Confirm (PowerMenu):**
```
qs ipc call powermenu show
# Arrow to "Lock", Enter → runs (no confirm step, lock is not danger)
qs ipc call powermenu show
# Arrow to "Shutdown", Enter → confirm dialog appears on top
# Verify: Cancel button has focus ring (NOT danger)
# Press Tab → focus moves to danger
# Press Esc → confirm closes, picker still open, focus back on search
# Arrow to "Shutdown", Enter → confirm appears
# Click scrim → confirm closes, picker stays
# Enter → confirm appears, Tab → danger focused, Enter → system shuts down
#   (comment out _proc.running before running this test)
```

**Token migration sanity:**
```
grep -rn "Theme\." /opt/arche/shell/components/PickerDialog.qml
  → expected: no matches
grep -rn "Theme\." /opt/arche/shell/components/ControlCenter.qml
  → expected: no matches
grep -rn "Theme\." /opt/arche/shell/components/picker/
  → expected: no matches
```

**Multi-monitor scrim:**
- Open launcher on eDP-1. Click on HDMI-A-1. Launcher dismisses (monitor-left), HDMI-A-1 windows receive click normally.
- Verify no compositor-wide blur ever triggers.

**Animation:**
- Open + close the launcher 10× rapidly. Confirm no mid-flight cuts (trap #9 regression). `offsetScale` driver should land cleanly.

**Journal:**
- Throughout, journal must stay clean. Any `TypeError: Cannot read property of undefined` on `dialogSurface` / `dialogBorder` / `dialogScrim` / `radiusDialog` / `durationDialog` indicates the orchestrator forgot a role — halt, not a coder fix.

---

## Open questions for orchestrator

1. `Motion.easeDialog` asymmetric (accel on close, decel on open) vs. symmetric `Motion.standard`. Designer chose symmetric — simpler `Behavior`, matches `ControlCenter`. Orchestrator can split into `SequentialAnimation` if polish demands it.
2. `Theme.controlCenterWidth` fix — inline `Sizing.px(420)` vs. promote to `Sizing.controlCenterWidth`. Designer suggests inline since ControlCenter is the only consumer.

---

## Summary

`StyledDialog` extends `StyledWindow` with a role enum (`Picker` | `Confirm`), a single `open` bool, and one `dismissed(reason: string)` signal carrying the closure cause as a string ("outside" | "esc" | "commit" | "cancel" | "action" | "monitor-left"). Motion is a single `offsetScale` numeric driver feeding opacity + 8px y-translate on both scrim and card via a new `Anim.type: "dialog"` preset, eliminating the twin-Behavior race in today's `PickerDialog`. PowerMenu gains a `danger: true` field on actions — shutdown and reboot trigger a `Confirm` dialog whose Cancel button is default-focused (danger is opt-in via Tab). Eleven new theme roles (`Colors.dialogScrim/dialogSurface/dialogBorder/dangerBg/dangerBorder`, `Shape.radiusDialog`, `Spacing.dialogPad/dialogContentGap/dialogInset`, `Motion.durationDialog/easeDialog`, `Effects.shadowDialog*`) are required before coding. `CalendarPanel` is explicitly deferred because it's anchor-top-center (drawer-shaped), not center (dialog-shaped); a sibling `StyledDrawer` is a follow-up.
