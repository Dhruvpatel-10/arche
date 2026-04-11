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
├── themes/                 # source of truth for all visual values
│   ├── schema.sh           # variable registry — names, types, defaults
│   ├── ember.sh            # active theme (warm amber on deep charcoal)
│   └── active -> ember.sh  # symlink to current theme
│
├── templates/              # .tmpl files rendered by theme engine (envsubst)
│   ├── hypr/               # colors, cursor, fonts for Hyprland + hyprlock
│   ├── kitty/              # terminal colors + fonts
│   ├── waybar/             # bar stylesheet
│   ├── mako/               # notification config
│   ├── gtk-3.0/            # GTK3 settings (theme, icons, cursor, fonts)
│   ├── gtk-4.0/            # GTK4 settings + CSS overrides
│   ├── qt6ct/              # Qt6 config (icons, fonts)
│   ├── zathura/            # PDF viewer colors
│   ├── mpv/                # media player fonts
│   └── ...                 # btop, tmux, walker, syshud
│
├── packages/               # package registry — data only, no logic
│   └── *.sh                # each file: PACMAN_PKGS=() and AUR_PKGS=()
│
├── scripts/                # numbered setup scripts + shared library
│   ├── lib.sh              # shared primitives (log, install, stow, etc.)
│   ├── theme.sh            # theme engine: apply / switch / list
│   └── 00-preflight.sh ... 12-appearance.sh
│
├── vendor/                 # third-party source shipped as-is (see D013)
│   └── sddm-silent/        # SilentSDDM theme for SDDM (glassmorphism)
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
    ├── bash/               # shell config (D016)
    ├── kitty/              # terminal behavior
    ├── starship/           # prompt config
    ├── mpv/                # media player
    ├── hypr/               # compositor + hyprlock + hypridle
    ├── waybar/             # status bar modules
    ├── nvim/               # LazyVim editor
    ├── walker/             # app launcher
    ├── zathura/            # PDF viewer behavior
    └── ...                 # tmux, btop, kvantum, qt6ct, etc.
```

## The Three-Layer Config Split

Every config file belongs to exactly one layer. Never mix them.

### Layer 1: Templates

Configs that contain **colors, fonts, sizes, cursors, icons, or spacing**. Rendered by
`scripts/theme.sh` using `envsubst`. Output is gitignored. Lives in
`templates/`.

Examples: `waybar/style.css`, `gtk-3.0/settings.ini`, `hypr/envs.conf`

### Layer 2: Stow Packages

Configs that contain **behavior**: keybinds, module lists, rules, logic.
Symlinked directly via GNU Stow. Committed as-is. Lives in `stow/`.

Examples: `hyprland.conf`, `waybar/config.jsonc`, `bash/.bashrc`

### Layer 3: Generated Output

Files produced by rendering templates. Live in `~/.config/`. Never committed.
Listed in `.gitignore`.

Examples: `~/.config/waybar/style.css`, `~/.config/hypr/envs.conf`

## Theme System

`themes/ember.sh` exports shell variables consumed by templates:

- Colors: `COLOR_BG`, `COLOR_FG`, `COLOR_ACCENT`, `COLOR_WARN`, etc.
- Fonts: `FONT_SANS`, `FONT_MONO`, `FONT_SIZE_*`
- Layout: `RADIUS`, `BORDER_SIZE`, `GAP`, `BAR_HEIGHT`
- Appearance: `CURSOR_THEME`, `CURSOR_SIZE`, `ICON_THEME`, `GTK_THEME`

`themes/schema.sh` is the single source of truth for variable names, types, and defaults.
`scripts/theme.sh` renders all templates and reloads affected services.
nvim is excluded — it uses catppuccin/nvim plugin directly.

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
stow/bash/.bashrc                  →  ~/.bashrc
stow/mpv/.config/mpv/mpv.conf      →  ~/.config/mpv/mpv.conf
```

The `stow_pkg` function in `lib.sh`:

```bash
stow_pkg() { stow -d "$ARCHE/stow" -t "$HOME" --no-folding "$1"; }
```

## Bootstrap Flow

`bootstrap.sh` runs numbered scripts `00` through `12` in order. Each script
is independently runnable (`bash scripts/05-hyprland.sh`). Each section
prompts before running (y/N/a for all). The orchestrator captures exit codes
and prints a final summary table.

Assumes: repo cloned, user has sudo, running on Arch Linux.
Does not: clone repo, configure SSH, set up secrets.

## System Stack

| Layer        | Tool                                         |
|--------------|----------------------------------------------|
| OS           | Arch Linux (btrfs, Limine bootloader)        |
| Compositor   | Hyprland via uwsm, SDDM + SilentSDDM theme   |
| Shell        | bash + ble.sh + bash-preexec + atuin + bash-completion + starship (D016) |
| Terminal     | Kitty                                        |
| Editor       | Neovim (LazyVim)                             |
| Bar          | Waybar                                       |
| Launcher     | Rofi (rofi-wayland, combi mode)              |
| Notifications| Mako                                         |
| GPU          | NVIDIA open-dkms (RTX 4060 Laptop)           |
| Audio        | PipeWire full stack                          |
| Theme        | Ember (warm amber on deep charcoal)          |
