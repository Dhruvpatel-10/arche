---
name: stow-workflow
description: How to move a config into arche and stow it. Use when adding any new ~/.config entry to the arche repo.
disable-model-invocation: true
---

# Stow Workflow

## Prerequisites — decide the layer first

Before stowing, determine which layer each config file belongs to:
- **Behavior config** (keybinds, modules, rules) → stow package, committed as-is
- **Visual config** (colors, fonts, sizes, cursors, icons) → template in `templates/`, rendered by theme.sh
- **Mixed** → split into two files: behavior in stow, visual in template. Stow config uses `include`/`source` to pull in rendered output.

Only behavior configs go into the stow package. Visual configs go into `templates/`.

## Directory structure
Config `foo` lives at `~/.config/foo/` goes into arche as:
`~/arche/stow/foo/.config/foo/`

Stow is run from `~/arche/`:
`stow -d stow -t $HOME foo` creates symlinks under `~/.config/foo/`

## Step-by-step pattern

1. **Check not already stowed**
   `[ -L "$HOME/.config/$1" ] && echo "Already stowed" && exit 0`

2. **Take a snapshot**
   `snapper create --description "pre-stow-$1"`

3. **Create arche target directory**
   `mkdir -p "$HOME/arche/stow/$1/.config/$1"`

4. **Copy (not move) config first**
   `cp -r "$HOME/.config/$1/." "$HOME/arche/stow/$1/.config/$1/"`

5. **Split visual from behavior**
   Move any color/font/size/cursor/icon values out of the stow config into `templates/$1/`.
   Replace them with envsubst placeholders (`${COLOR_BG}`, `${FONT_MONO}`, `${CURSOR_THEME}`, etc.).
   Use `include`/`source` in the stow config to reference the rendered output.

6. **Verify content copied correctly**
   `diff -r "$HOME/.config/$1/" "$HOME/arche/stow/$1/.config/$1/"`

7. **Remove original**
   `rm -rf "$HOME/.config/$1"`

8. **Stow**
   `cd "$HOME/arche" && stow -d stow -t $HOME --no-folding $1`

9. **Verify symlink**
   `[ -L "$HOME/.config/$1" ] && echo "OK: symlink created" || echo "FAIL: no symlink"`

10. **If templates exist, render them**
    `bash scripts/theme.sh apply $1`

11. **Verify config still works** (app-specific)

12. **Update packages/ file if needed**
    Add to the relevant `packages/*.sh` arrays.

13. **Update script if needed**
    Add stow_pkg call to the relevant `scripts/<nn>-<name>.sh`.

14. **Commit**
    `git -C "$HOME/arche" add -A && git -C "$HOME/arche" commit -m "feat($1): stow config"`

## Arguments
$ARGUMENTS = config name (e.g. `mako`, `waybar`, `hypr`)
