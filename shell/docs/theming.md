# Theming

Modular theme system. Each concern lives in its own singleton under
`theme/`. `Theme.qml` at the root is a backwards-compatible facade so
existing components keep working while callers migrate to direct module
imports.

## Modules

| File                   | Exposes                                           |
| ---------------------- | ------------------------------------------------- |
| `theme/Sizing.qml`     | `fontScale`, `layoutScale`, `px()`, `fpx()`       |
| `theme/Colors.qml`    | semantic colors (bg, fg, accent, state)           |
| `theme/Typography.qml` | font families + semantic size ladder + weights   |
| `theme/Spacing.qml`    | `xs` / `sm` / `md` / `lg` / `xl` on a 4px grid   |
| `theme/Shape.qml`      | radii + border widths                             |
| `theme/Effects.qml`    | opacity, shadow, surface-alpha tokens             |
| `theme/Motion.qml`     | animation durations + easings                     |

## Usage

```qml
import "../theme"

Rectangle {
    color: Colors.card
    radius: Shape.radiusLg
    border { color: Colors.border; width: Shape.borderThin }

    Text {
        font.family: Typography.fontSans
        font.pixelSize: Typography.fontBody
        font.weight: Typography.weightDemiBold
        color: Colors.fg
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.durationMed
            easing.type: Motion.easeOut
        }
    }
}
```

The legacy facade `Theme.xxx` still works for existing call sites. Don't
reach for it in new code.

## Scaling — two axes

Both default to `1.0`. Both clamp to `[0.75, 2.0]`.

- `ARCHE_SHELL_FONT_SCALE`   — typography only. Accessibility knob.
- `ARCHE_SHELL_LAYOUT_SCALE` — chrome: padding, radii, panel widths.

```sh
# default — 14" laptop @ 1080p, 16" @ 2.5K
ARCHE_SHELL_LAYOUT_SCALE=1.15 quickshell -p shell.qml  # 4K external
ARCHE_SHELL_FONT_SCALE=0.9    quickshell -p shell.qml  # denser text
```

Components never read the env vars directly — they call `Sizing.px(38)` or
`Sizing.fpx(14)`, which apply the scale and round.

## Philosophy

### Colors
Every color is a role, not a hue. `bg` means "window background", not
"dark gray". If the role doesn't exist yet, don't reach for `bgAlt`
because it "looks right" — add a role to `Colors.qml` first. The full
surface ladder is documented in `Colors.qml`.

### Corners
Pick by surface type, not pixel count:

- small chips → `radiusXs`
- row groups → `radiusSm`
- tiles → `radiusTile`
- pills (bar items) → `radiusPill`
- drawer cards → `radiusLg`

All scale with `layoutScale` so a pill stays pill-shaped on 4K.

### Blurring
Backdrop blur is **off** for all Quickshell surfaces at the compositor
level (`stow/hypr/.config/hypr/looknfeel.conf`, `layerrule = blur 0`).

Cards use fully-opaque hex colors. Depth is expressed through **shadow**
and **surface contrast**, not blur. This eliminates the halo that
appears around rounded corners and between stacked layers when blur is
enabled through the compositor.

If you think you want blur, reach for either:

1. a `shadowBlur` on the surface above, or
2. a surface step up (`card` → `bgSurface` → `tileBg`).

### Motion
One palette, used everywhere:

- `durationFast` (120ms) — local interaction (hover, button press)
- `durationMed`  (220ms) — drawer / popover reveal
- `durationSlow` (320ms) — coordinated multi-property transition

Easings (`easeOut`, `easeInOut`, `easeSpring`) line up with the
Apple-style bezier curves in Hyprland's `animations` block, so
window-level and shell-level motion feel like one system.

## Extending

When adding a new token:

1. Put it in the module whose concern it fits. No "misc" bucket.
2. Name it by role, not value (`shadowBlur`, not `blur20`).
3. If it scales with screen, wrap it in `Sizing.px()` / `Sizing.fpx()`.
4. Don't add to `Theme.qml` — that's facade-only. If an existing
   component references a new token by its legacy name, add the facade
   passthrough after the module value lands.

## Files

```
arche-shell/
├── Theme.qml              # legacy facade — forwards to modules
├── theme/
│   ├── qmldir
│   ├── Sizing.qml
│   ├── Colors.qml
│   ├── Typography.qml
│   ├── Spacing.qml
│   ├── Shape.qml
│   ├── Effects.qml
│   └── Motion.qml
└── docs/
    ├── theming.md         # this file
    └── typography.md      # per-subsystem deep dive
```
