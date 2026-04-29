# Architecture

## Overview

This is a personal Arch Linux dotfiles repository. The goal: clone on a fresh
Arch install, run `bootstrap.sh`, get a fully configured system. Every decision
is **minimal**, **idempotent**, **declarative**, and **auditable**.

## Repository Layout

```
/opt/arche/                  # ~/arche → /opt/arche per user, see D014
├── bootstrap.sh            # orchestrator — runs all scripts in order
├── Justfile                # day-to-day interface: just <target>
├── CLAUDE.md               # AI assistant standing instructions
│
├── docs/                   # decision records, architecture, status
│
├── theming/themes/                 # source of truth for all visual values
│   ├── schema.sh           # variable registry — names, types, defaults
│   ├── ember.sh            # active theme (warm amber on deep charcoal)
│   └── active -> ember.sh  # symlink to current theme
│
├── theming/templates/              # .tmpl files rendered by theme engine (envsubst)
│   ├── kitty/              # terminal colors + fonts
│   ├── hypr/               # colors, envs, hyprlock fonts/colors (D023)
│   ├── rofi/               # launcher theme (D023)
│   ├── gtk-3.0/            # GTK3 settings (theme, icons, cursor, fonts)
│   ├── gtk-4.0/            # GTK4 settings + CSS overrides
│   ├── qt6ct/              # Qt6 config (icons, fonts)
│   ├── mpv/                # media player fonts
│   └── ...                 # btop, tmux, starship, legion
│
├── packages/               # package registry — data only, no logic
│   └── *.sh                # each file: PACMAN_PKGS=() and AUR_PKGS=()
│
├── scripts/                # numbered setup scripts + shared library
│   ├── lib.sh              # shared primitives (log, install, stow, etc.)
│   ├── theme.sh            # theme engine: apply / switch / list
│   └── 00-preflight.sh ... 11-appearance.sh
│
├── tools/                  # custom binaries
│   └── bin/                # pre-built binaries from external repos
│       └── arche-legion    # Lenovo Vantage replacement
│
├── system/                 # system configs (/etc/) — symlinked by scripts
│   ├── etc/
│   └── usr/local/bin/
│
└── stow/                   # behavior configs — symlinked via GNU Stow
    ├── fish/               # shell config (D018 — restored from D003)
    ├── kitty/              # terminal behavior
    ├── starship/           # prompt config
    ├── mpv/                # media player
    ├── hypr/               # Hyprland compositor (D023 — restored)
    ├── rofi/               # launcher (D023 — restored)
    ├── cliphist/           # clipboard history (D023 — restored)
    ├── hyprland-preview-share-picker/  # screen-share picker (D023)
    ├── arche-scripts/      # user scripts (wallpaper, popup, powermenu, …)
    ├── nvim/               # LazyVim editor
    └── ...                 # tmux, btop, kvantum, qt6ct, etc.
```

## The Three-Layer Config Split

Every config file belongs to exactly one layer. Never mix them.

### Layer 1: Templates

Configs that contain **colors, fonts, sizes, cursors, icons, or spacing**. Rendered by
`theming/engine.sh` using `envsubst`. Output is gitignored. Lives in
`theming/templates/`.

Examples: `kitty/theme.conf`, `gtk-3.0/settings.ini`, `btop/arche.theme`

### Layer 2: Stow Packages

Configs that contain **behavior**: keybinds, module lists, rules, logic.
Symlinked directly via GNU Stow. Committed as-is. Lives in `stow/`.

Examples: `fish/config.fish`, `kitty/kitty.conf`, `hypr/bindings.conf`

### Layer 3: Generated Output

Files produced by rendering templates. Live in `~/.config/`. Never committed.
Listed in `.gitignore`.

Examples: `~/.config/kitty/theme.conf`, `~/.config/btop/arche.theme`

## Theme System

`theming/themes/ember.sh` exports shell variables consumed by templates:

- Colors: `COLOR_BG`, `COLOR_FG`, `COLOR_ACCENT`, `COLOR_WARN`, etc.
- Fonts: `FONT_SANS`, `FONT_MONO`, `FONT_SIZE_*`
- Layout: `RADIUS`, `BORDER_SIZE`, `GAP`, `BAR_HEIGHT`
- Appearance: `CURSOR_THEME`, `CURSOR_SIZE`, `ICON_THEME`, `GTK_THEME`

`theming/themes/schema.sh` is the single source of truth for variable names, types, and defaults.
`theming/engine.sh` renders all templates and reloads affected services.
nvim is excluded — it uses catppuccin/nvim plugin directly.
Quickshell theme values live in the external arche-shell repo (`Theme.qml`) —
kept in sync with ember manually for now (see status.md Q1).

## Package Management

Each `packages/*.sh` file declares two arrays:

```bash
PACMAN_PKGS=( ... )
AUR_PKGS=( ... )
```

`lib.sh` provides `install_group <file>` to install both arrays idempotently.
Scripts never call `pacman` or `paru` directly. Removal is always manual
(`paru -Rns`).

## Stow Convention

All stow packages live under `stow/`. Each package mirrors the home directory
structure it targets:

```
stow/fish/.config/fish/config.fish →  ~/.config/fish/config.fish
stow/mpv/.config/mpv/mpv.conf      →  ~/.config/mpv/mpv.conf
```

The `stow_pkg` function in `lib.sh`:

```bash
stow_pkg() { stow -d "$ARCHE/stow" -t "$HOME" --no-folding "$1"; }
```

## Bootstrap Flow

`bootstrap.sh` runs numbered scripts `00` through `11` in order. Each script
is independently runnable (`bash scripts/05-hyprland.sh`). Each section
prompts before running (y/N/a for all). The orchestrator captures exit codes
and prints a final summary table.

Assumes: repo cloned, user has sudo, running on Arch Linux.
Does not: clone repo, configure SSH, set up secrets.

## System Stack

| Layer        | Tool                                                   |
|--------------|--------------------------------------------------------|
| OS           | Arch Linux (btrfs, systemd-boot with UKIs)             |
| Pre-boot UI  | Plymouth + `arche` theme, TPM2+PIN via sd-encrypt (D024)|
| Compositor   | Hyprland (Wayland) via uwsm (D023)                     |
| Greeter      | SDDM, custom `arche` theme (D025)                      |
| Panel        | Quickshell / arche-shell (D023) — bar + control-center |
| Notifications| Quickshell ToastLayer / NotificationsList              |
| OSD          | Quickshell                                             |
| Launcher     | rofi-wayland                                           |
| Lock / idle  | hyprlock / hypridle                                    |
| Wallpaper    | awww (swww successor — D026)                           |
| Shell        | fish + atuin + fisher + starship (D018)                |
| Terminal     | Kitty                                                  |
| Editor       | Neovim (LazyVim)                                       |
| GPU          | NVIDIA open-dkms (RTX 4060 Laptop)                     |
| Audio        | PipeWire full stack                                    |
| Theme        | Ember (warm amber on deep charcoal)                    |
