# Theme Standard

Single source of truth for the arche theme system.
Every theme, template, and rendering step derives from this specification.

---

## Architecture

```
themes/
  schema.sh          # THE contract — all variable names, types, defaults
  ember.sh           # theme implementation (must satisfy schema)
  nord.sh            # another theme (same contract)
  active -> ember.sh # symlink to current theme

scripts/
  lib.sh             # theme_render: sources schema, validates, exports, renders
```

**One rule:** schema.sh is the only place variable names are listed.
Theme files assign values. lib.sh reads the schema to know what to export.
Nothing is hardcoded anywhere else.

---

## Schema Design

### Variable Registry (`theming/themes/schema.sh`)

The schema defines every valid theme variable as a member of a typed group.
Each group is a bash array. Membership in the array IS the type declaration.

```bash
# ─── Color variables (value must match: #[0-9a-fA-F]{6}) ───

SCHEMA_COLORS_REQUIRED=(
    # Core palette — every theme MUST define these
    COLOR_BG              # Base background
    COLOR_BG_ALT          # Mantle / darker panels
    COLOR_BG_SURFACE      # Surface0 / raised elements
    COLOR_FG              # Primary text
    COLOR_FG_MUTED        # Secondary text / subtext0
    COLOR_ACCENT          # Primary accent
    COLOR_ACCENT_ALT      # Secondary accent
    COLOR_SUCCESS         # Positive state
    COLOR_WARN            # Warning state
    COLOR_CRITICAL        # Error / danger state
    COLOR_BORDER          # Borders and dividers
)

SCHEMA_COLORS_OPTIONAL=(
    # Extended palette — theme may omit, falls back to defaults
    COLOR_CURSOR          # Cursor color (default: COLOR_FG)
    COLOR_TEAL            # (default: COLOR_ACCENT_ALT)
    COLOR_PINK            # (default: COLOR_CRITICAL)
    COLOR_MAUVE           # (default: COLOR_ACCENT_ALT)
    COLOR_PEACH           # (default: COLOR_WARN)
    COLOR_SKY             # (default: COLOR_ACCENT_ALT)
    COLOR_OVERLAY0        # (default: COLOR_FG_MUTED)
    COLOR_OVERLAY1        # (default: COLOR_FG_MUTED)
    COLOR_SUBTEXT1        # (default: COLOR_FG_MUTED)
    COLOR_CRUST           # (default: COLOR_BG_ALT)
    COLOR_SURFACE1        # (default: COLOR_BORDER)
    COLOR_SURFACE2        # (default: COLOR_BORDER)
)

# ─── Font variables (value: string) ───

SCHEMA_FONTS_REQUIRED=(
    FONT_SANS             # UI / body font
    FONT_MONO             # Code / terminal font
)

# ─── Integer variables (value: non-negative integer) ───

SCHEMA_INTEGERS_REQUIRED=(
    FONT_SIZE_NORMAL      # Default font size (px/pt)
    FONT_SIZE_SMALL       # Small text
    FONT_SIZE_BAR         # Status bar text
    RADIUS                # Default border-radius (px)
    BORDER_SIZE           # Default border width (px)
    GAP                   # Window/element gap (px)
    BAR_HEIGHT            # Status bar height (px)
)

SCHEMA_INTEGERS_OPTIONAL=(
    NOTIF_WIDTH           # (default: 400)
    NOTIF_MARGIN          # (default: 12)
    NOTIF_PADDING_V       # (default: 16)
    NOTIF_PADDING_H       # (default: 20)
    NOTIF_RADIUS          # (default: RADIUS)
    NOTIF_BORDER_SIZE     # (default: BORDER_SIZE)
    NOTIF_ICON_SIZE       # (default: 36)
    NOTIF_GAP             # (default: 14)
    NOTIF_FONT_SIZE       # (default: FONT_SIZE_NORMAL)
    NOTIF_FONT_SIZE_SMALL # (default: FONT_SIZE_SMALL)
    NOTIF_TIMEOUT         # (default: 5000)
)

# ─── Special variables (value: hex alpha suffix without #) ───

SCHEMA_ALPHA_OPTIONAL=(
    COLOR_BG_ALPHA        # Alpha suffix for rgba (default: D0)
)
```

### Key Properties

- **REQUIRED** arrays = the theme MUST define every member. Validation fails otherwise.
- **OPTIONAL** arrays = the theme MAY omit them. Schema provides sensible defaults
  derived from required values (e.g. `COLOR_CURSOR` defaults to `COLOR_FG`).
- **Array membership is the type.** `SCHEMA_COLORS_*` members must be `#hex`.
  `SCHEMA_INTEGERS_*` members must be non-negative integers. No separate type map.
- **Comments in the arrays are the docs.** No separate documentation to keep in sync.

---

## Theme File Contract

A theme file is a plain bash file that assigns values to schema variables.
It must NOT: source other files, run commands, define functions, or export anything.

```bash
# Nord — cool blue palette
# theming/themes/nord.sh

# ─── Required Colors ───
COLOR_BG="#2e3440"
COLOR_BG_ALT="#292e39"
COLOR_BG_SURFACE="#3b4252"
COLOR_FG="#eceff4"
COLOR_FG_MUTED="#828997"
COLOR_ACCENT="#88c0d0"
COLOR_ACCENT_ALT="#81a1c1"
COLOR_SUCCESS="#a3be8c"
COLOR_WARN="#ebcb8b"
COLOR_CRITICAL="#bf616a"
COLOR_BORDER="#434c5e"

# ─── Required Fonts ───
FONT_SANS="IBM Plex Sans"
FONT_MONO="MesloLGS Nerd Font Mono"

# ─── Required Integers ───
FONT_SIZE_NORMAL="10"
FONT_SIZE_SMALL="8"
FONT_SIZE_BAR="10"
RADIUS="8"
BORDER_SIZE="2"
GAP="5"
BAR_HEIGHT="38"

# ─── Optional (omitted = schema defaults apply) ───
COLOR_CURSOR="#d8dee9"
COLOR_TEAL="#8fbcbb"
COLOR_MAUVE="#b48ead"
```

### Rules for Theme Authors

1. Define ALL required variables — validation will reject your theme otherwise.
2. Optional variables may be omitted — defaults are derived from your required values.
3. Values only. No `$(command)`, no arithmetic, no sourcing, no functions.
4. Comments encouraged — describe your design intent, not the variable purpose (schema has that).
5. Order: required colors, required fonts, required integers, then optionals.

---

## Rendering Pipeline

When `theme_render` runs, the following happens in order:

```
1. SOURCE  schema.sh       → load variable group arrays
2. SOURCE  theming/themes/active   → load theme values into shell
3. DEFAULTS                → fill optional vars from required vars
4. VALIDATE                → check all required vars set + type check
5. DERIVE  _NOHASH         → strip # from every SCHEMA_COLORS_* member
6. EXPORT  all vars        → iterate schema arrays, export each
7. RENDER  envsubst        → process .tmpl files to ~/.config/
8. RELOAD  services        → per-component reload
```

### Step 3: Defaults (pseudocode)

```bash
# Applied AFTER sourcing theme, BEFORE validation
: "${COLOR_CURSOR:=$COLOR_FG}"
: "${COLOR_TEAL:=$COLOR_ACCENT_ALT}"
: "${COLOR_PINK:=$COLOR_CRITICAL}"
: "${COLOR_MAUVE:=$COLOR_ACCENT_ALT}"
: "${COLOR_PEACH:=$COLOR_WARN}"
: "${COLOR_SKY:=$COLOR_ACCENT_ALT}"
: "${COLOR_OVERLAY0:=$COLOR_FG_MUTED}"
: "${COLOR_OVERLAY1:=$COLOR_FG_MUTED}"
: "${COLOR_SUBTEXT1:=$COLOR_FG_MUTED}"
: "${COLOR_CRUST:=$COLOR_BG_ALT}"
: "${COLOR_SURFACE1:=$COLOR_BORDER}"
: "${COLOR_SURFACE2:=$COLOR_BORDER}"
: "${COLOR_BG_ALPHA:=D0}"
: "${NOTIF_WIDTH:=400}"
: "${NOTIF_MARGIN:=12}"
: "${NOTIF_PADDING_V:=16}"
: "${NOTIF_PADDING_H:=20}"
: "${NOTIF_RADIUS:=$RADIUS}"
: "${NOTIF_BORDER_SIZE:=$BORDER_SIZE}"
: "${NOTIF_ICON_SIZE:=36}"
: "${NOTIF_GAP:=14}"
: "${NOTIF_FONT_SIZE:=$FONT_SIZE_NORMAL}"
: "${NOTIF_FONT_SIZE_SMALL:=$FONT_SIZE_SMALL}"
: "${NOTIF_TIMEOUT:=5000}"
```

### Step 4: Validation

```bash
theme_validate() {
    local fail=0

    # Required colors — must be set and match #hex6
    for var in "${SCHEMA_COLORS_REQUIRED[@]}"; do
        [[ -z "${!var:-}" ]] && log_err "Missing: $var" && fail=1 && continue
        [[ "${!var}" =~ ^#[0-9a-fA-F]{6}$ ]] || { log_err "$var: bad hex '${!var}'"; fail=1; }
    done

    # Optional colors — if set, must match #hex6
    for var in "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        [[ -n "${!var:-}" && ! "${!var}" =~ ^#[0-9a-fA-F]{6}$ ]] && \
            { log_err "$var: bad hex '${!var}'"; fail=1; }
    done

    # Required fonts — must be non-empty strings
    for var in "${SCHEMA_FONTS_REQUIRED[@]}"; do
        [[ -z "${!var:-}" ]] && log_err "Missing: $var" && fail=1
    done

    # Required integers — must be set and numeric
    for var in "${SCHEMA_INTEGERS_REQUIRED[@]}"; do
        [[ -z "${!var:-}" ]] && log_err "Missing: $var" && fail=1 && continue
        [[ "${!var}" =~ ^[0-9]+$ ]] || { log_err "$var: not integer '${!var}'"; fail=1; }
    done

    # Optional integers — if set, must be numeric
    for var in "${SCHEMA_INTEGERS_OPTIONAL[@]}"; do
        [[ -n "${!var:-}" && ! "${!var}" =~ ^[0-9]+$ ]] && \
            { log_err "$var: not integer '${!var}'"; fail=1; }
    done

    # Alpha — if set, must be 2-char hex
    for var in "${SCHEMA_ALPHA_OPTIONAL[@]}"; do
        [[ -n "${!var:-}" && ! "${!var}" =~ ^[0-9a-fA-F]{2}$ ]] && \
            { log_err "$var: bad alpha '${!var}'"; fail=1; }
    done

    return $fail
}
```

### Step 5–6: Derive and Export (schema-driven, no hardcoded lists)

```bash
# _NOHASH for all color variables — iterate the schema, not a manual list
for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
    [[ -n "${!var:-}" ]] && export "${var}_NOHASH=${!var#\#}"
done

# Export everything — single loop over all schema groups
for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}" \
           "${SCHEMA_FONTS_REQUIRED[@]}" \
           "${SCHEMA_INTEGERS_REQUIRED[@]}" "${SCHEMA_INTEGERS_OPTIONAL[@]}" \
           "${SCHEMA_ALPHA_OPTIONAL[@]}"; do
    [[ -n "${!var:-}" ]] && export "$var"
done
export DOLLAR='$'
```

**This is the key win:** adding a new variable means adding it to one schema array.
No touching lib.sh exports. No touching the _NOHASH loop. No forgetting a step.

---

## Template Audit (lint-time)

Templates must only reference schema-defined variables. The test runner validates:

```bash
# Extract ${VAR} references from all templates
# Check each against schema arrays
# Flag any variable not in any SCHEMA_* array (except DOLLAR and *_NOHASH)
```

This catches:
- Typos in template variables (`${COLOR_ACCEN}`)
- Variables removed from schema but still in templates
- New template vars added without schema registration

Add to `tests/run.sh` under the lint level.

---

## Adding a New Theme

```bash
# 1. Copy the skeleton
cp theming/themes/ember.sh theming/themes/mytheme.sh

# 2. Edit values — schema.sh comments tell you what each variable is
$EDITOR theming/themes/mytheme.sh

# 3. Validate
bash theming/engine.sh validate mytheme

# 4. Preview (render without switching active)
bash theming/engine.sh preview mytheme

# 5. Switch
bash theming/engine.sh switch mytheme
```

### `theme.sh validate <name>`

Sources schema + theme file, runs `theme_validate`, reports pass/fail.
Does NOT render or switch anything. Safe to run on untested themes.

### `theme.sh preview <name>` (future)

Renders templates to a temp dir, opens a diff against current rendered output.
Lets you see exactly what would change before committing to a switch.

---

## Adding a New Variable

1. Add to the appropriate array in `theming/themes/schema.sh`
2. If optional: add default in the defaults block
3. Add value to each theme file in `theming/themes/`
4. Use `${VAR_NAME}` in templates
5. Run `just test` — lint will verify templates only use schema vars

That's it. No need to touch lib.sh exports, _NOHASH loops, or any other plumbing.

---

## Removing a Variable

1. Remove from `theming/themes/schema.sh`
2. Remove from all theme files
3. Remove `${VAR_NAME}` from all templates
4. Run `just test` — lint catches any stragglers

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Hardcode hex colors in stow configs | Use a template, reference `${COLOR_*}` |
| Hardcode font names in stow configs | Use a template, reference `${FONT_*}` |
| Hardcode pixel sizes for radii/gaps | Use a template, reference `${RADIUS}`, `${GAP}`, etc. |
| Add exports to lib.sh manually | Add the variable to schema.sh — export is automatic |
| Copy _NOHASH generation for new colors | Schema-driven — all colors get _NOHASH automatically |
| Put theme logic in theme files | Theme files are pure assignment. Logic lives in lib.sh |
| Reference `${VAR}` not in schema | Lint will catch it. Register in schema first |

---

## File Ownership

| File | Owns | Touches |
|------|------|---------|
| `theming/themes/schema.sh` | Variable names, types, defaults | Nothing — pure data |
| `themes/*.sh` | Color/font/size values | Nothing — pure assignment |
| `scripts/lib.sh` | Validation, export, render pipeline | Reads schema + theme |
| `templates/*.tmpl` | Component visuals | References schema vars via `${VAR}` |
| `tests/run.sh` | Lint: template vars vs schema | Reads schema + templates |

No file does another file's job. No information is duplicated across files.

---

## Migration Path

Current state has hardcoded export lists in lib.sh and manual _NOHASH loops.
Migration is mechanical:

1. Create `theming/themes/schema.sh` with current variables
2. Replace lib.sh hardcoded exports with schema-driven loop
3. Replace lib.sh _NOHASH loop with schema-driven loop
4. Add `theme_validate` to lib.sh
5. Add `validate` command to theme.sh
6. Add template variable lint to tests/run.sh
7. Update CLAUDE.md theme section

All existing themes and templates continue to work unchanged.
The schema just formalizes what already exists.
