# Typography

Lives in `theme/Typography.qml`. Access via `Typography.xxx` after
`import "../theme"`. The legacy `Theme.xxx` facade still works. See
`docs/theming.md` for the overall theme architecture.

## Scale

Logical pixels pre-scale. `Typography` applies `Scale.fpx` (governed by
`ARCHE_SHELL_FONT_SCALE`) and rounds. Ladder is intentionally non-linear
— each step must be perceptibly distinct on the screens we ship on.

| Token         | Size | Role                                               |
| ------------- | ---- | -------------------------------------------------- |
| `fontMicro`   |  10  | Dense meta. Use only when the element must recede. |
| `fontCaption` |  12  | Badges, subtitles, dim meta, key hints.            |
| `fontBody`    |  14  | Default body copy, list row titles.                |
| `fontLabel`   |  15  | Emphasized row title, small icons.                 |
| `fontTitle`   |  17  | Modal search input, card section titles.           |
| `fontDisplay` |  30  | Hero numerics — clock, stat hero.                  |

Legacy aliases (live on the `Theme` facade, not `Typography`):

| Alias              | Maps to       |
| ------------------ | ------------- |
| `fontSize`         | `fontBody`    |
| `fontSizeSmall`    | `fontCaption` |
| `fontSizeLarge`    | `fontLabel`   |
| `fontSizeXL`       | `fontDisplay` |

## Picking a token

Pick by role, not by number. Ask: *what job does this text do?*

- Primary content of a row or card? → `fontBody`
- Secondary info (timestamp, dimensions, count)? → `fontCaption`
- User types into it? → `fontTitle`
- Single glyph (nerd-font icon) in a tile/button? → `fontLabel` or
  `fontTitle` depending on tile size
- The one number that dominates a card (time, big %)? → `fontDisplay`

If no token fits, the design is probably off — consider collapsing the
element into an adjacent role rather than adding a new size.

## Families

- `Typography.fontSans` — `IBM Plex Sans`. All UI text.
- `Typography.fontMono` — `MesloLGS Nerd Font Mono`. Glyphs, numeric
  tables, code previews, anything that needs `tnum` or nerd-font
  codepoints.

Always set `family` explicitly — don't rely on Qt defaults.

## Weights

Three in practice, exposed as presets:

- `Typography.weightNormal`   — default body text
- `Typography.weightMedium`   — de-emphasized labels that still want presence
- `Typography.weightDemiBold` — headings, emphasized row titles, active labels

Skip `Bold` and `Black` — too heavy for the dark palette; they smudge at
small sizes.

## Numeric content

For anything rendering numbers that change frequently (clocks, stats,
percentages) set `features: { "tnum": 1 }` to enable tabular figures, so
digits don't jitter as values tick.
