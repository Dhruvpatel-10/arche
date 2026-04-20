# Island design notes

The arche island is a center notch that morphs between seven states
(`idle`, `playing`, `volume`, `toast`, `recording`, `focus`, `expanded`).
This note captures the design rules the island follows. Read before
touching `components/IslandWindow.qml` or any content that feeds it.

## Principles (distilled from Apple Dynamic Island + adapted to desktop)

1. **The island is a flat void, not a card.** No border, no gradient, no
   drop shadow on the island itself. Its power is reading as a piece
   taken *out* of the screen — not a UI element floating *on top* of it.
2. **Near-black, not pure black.** `Colors.islandInk` (`#0d0e12`) sits a
   hair below `bg`/`bgAlt` so it still feels connected to the theme's
   warm-charcoal foundation. Pure `#000000` looks like a dead pixel patch
   at desktop scale.
3. **One primary datum in compact states.** Idle shows clock+date. Playing
   shows title+artist. Volume shows one bar + value. Toast shows summary
   bold + body dim. Never more than two lines of content per compact
   state, never a third action.
4. **Width leads, height follows (and inverts on collapse).** Expanding a
   state: width animates immediately, height starts ~40 ms later. That
   way the island reveals horizontally before it drops vertically, which
   avoids the brief "flat stretched rectangle" frame that looks like
   clipping. Collapsing reverses: height snaps back first, then width.
5. **Emphasized easing, minimal bounce.** QML's `Motion.emphasized`
   (`[0.05, 0.7, 0.1, 1.0]`) at 350 ms — accelerates, holds speed, decels
   without overshoot. Overshoot (`expressiveSpatial`) feels toy-like at a
   2560 px monitor scale even though it reads as delightful on a phone;
   reserve it for sub-10 px motion (icon pulse, REC dot breathing).
6. **Content cross-fade, not instant swap.** Outgoing content opacity
   drops in the first ~30 % of the morph (accel curve); incoming content
   opacity rises in the last ~40 % (decel curve). `visible: state === X`
   alone flashes mid-morph — the rect has already animated by the time
   the old content disappears, so the eye registers blank-then-change.
7. **Persistence = activity-bound. Dismissal = timer-bound.** Playing
   stays while a player is playing. Recording stays while recording.
   Toast auto-dismisses at 4 s; volume at 1.2 s. Expanded dismisses on
   outside click. Nothing is manually clearable in compact.
8. **Direct transitions only.** Never chain morphs (idle → collapsed →
   re-expand). Go straight between states. The only time the island
   passes through idle is if the prior activity ended before the new one
   started.
9. **Widths.** Compact states live in `[160, 320]`, expanded at `380`.
   Below 160 the pill-like proportions break; above ~520 it stops
   reading as a notch and becomes a bar. Current values fit cleanly.
10. **The top edge is always 0 radius.** The island is cut *out of* the
    top edge, not floating below it — top corners stay flush. Bottom
    corners are `min(14, height/2)` so compact states read as pill-ish
    and expanded reads as a rounded card.
11. **No hover chrome, ever.** The island's fill is one flat color —
    `Colors.islandInk`, always. Do not swap to a second shade on hover.
    A hole in the screen does not "light up" when the cursor passes
    over it; reacting there breaks the void illusion and, empirically,
    makes the notch feel jumpy and hard to click. Click-to-expand
    stays, but the cursor should only change to the pointing hand when
    there is actually something to expand into (an active player) —
    otherwise a plain arrow keeps the clock feeling passive.
12. **Content scales AND fades on state entry.** Every state container
    drives one numeric property `stateIn ∈ [0,1]` via a single
    Behavior. Opacity binds to `stateIn` directly; scale binds to
    `0.94 + 0.06 * stateIn`. That 6% growth on entry is the single
    biggest "feels alive" signal — content resolves into place instead
    of popping in flat. Use `Motion.standardDecel` at ~200 ms so the
    curve front-loads motion and settles softly.

## What to NOT do

- **No gradients on the island.** The warm-amber Ember accent palette
  loves gradients in *content* (badges, icons) — the island chrome never
  wears them. One flat fill.
- **No inner shadows, glows, or "glass" effects.** The compositor is
  blur-off by design; simulating glass in QML looks like cheap Rainmeter.
- **No more than one driver per morph.** One `state` → `targetW` /
  `targetH` / content opacities. Don't add parallel state machines for
  "hover compacting" or "attention wiggle" — they'll desync.
- **No multi-line text in compact.** If the summary wraps, truncate it
  with `elide: Text.ElideRight`. Two lines max, always.
- **No bouncy springs for the width/height morph.** Reserve
  `expressiveSpatial` / `OutBack` for small, decorative pops (album-art
  lift, chip press-release); the primary morph is `emphasized`.

## State cheat-sheet

| State       | Compact W | Content                                |
|-------------|-----------|----------------------------------------|
| `idle`      | 220       | HH:MM · Ddd · MMM d                    |
| `playing`   | 300       | art + title/artist + EQ bars           |
| `volume`    | 240       | icon + level bar + %                   |
| `toast`     | 320       | icon + summary/body                    |
| `recording` | 200       | pulsing dot + "REC" + mm:ss            |
| `focus`     | 240       | breathing ring + "Focus" + timer       |
| `expanded`  | 380×340   | full media player with scrub+transport |

## References

- WWDC23 — Design Dynamic Live Activities (Apple Developer)
- Made in Compose — Dynamic Island spring specs reverse-engineered
- UX Collective — Dynamic Island animations dissected into 4 principles

## Related files

- `components/IslandWindow.qml` — the surface + state routing
- `Ui.qml` — `islandState`, `tryExpand()`, `collapse()`, triggers
- `theme/Colors.qml` — `islandInk` token
- `theme/Motion.qml` — easing + duration tokens
- `Shortcuts.qml` — `island` IPC target for external triggers
