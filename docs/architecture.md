# Architecture

## Overview

A personal, cross-platform dotfiles repository built as a **shared core +
platform adapters + profiles** (D033). The goal: clone on a fresh machine, run
`bootstrap.sh`, get a fully configured system. The default target is Arch Linux
+ Hyprland; macOS (Apple Silicon) and a headless server are additional profiles.
Every decision is **minimal**, **idempotent**, **declarative**, and **auditable**.

## Repository Layout

```
/opt/arche/                  # ~/arche -> /opt/arche per user, see D014
├── install.sh              # OS-detecting curl installer -> clone -> exec bootstrap
├── bootstrap.sh            # single entrypoint: install / doctor / clean subcommands
├── Justfile                # day-to-day interface: just <target>
├── CLAUDE.md               # AI assistant standing instructions
│
├── docs/                   # decision records, architecture, status, redesign
│
├── theming/themes/                 # source of truth for all visual values
│   ├── schema.sh           # variable registry — names, types, defaults
│   ├── ember.sh            # active theme (warm amber on deep charcoal)
│   └── active -> ember.sh  # symlink to current theme
│
├── theming/templates/              # .tmpl files rendered by theme engine (envsubst)
│   ├── kitty/              # terminal colors + fonts
│   ├── hypr/               # colors, envs, hyprlock fonts/colors (D023)
│   ├── gtk-3.0/            # GTK3 settings (theme, icons, cursor, fonts)
│   ├── gtk-4.0/            # GTK4 settings + CSS overrides
│   ├── qt6ct/              # Qt6 config (icons, fonts)
│   ├── mpv/                # media player fonts
│   └── ...                 # btop, tmux, starship, legion
│
├── packages/               # package registry — data only, no logic
│   └── *.reg               # tool DSL: tool <name> arch=kind:pkg macos=kind:pkg
│
├── core/                   # platform-agnostic engine (bash 3.2 safe)
│   ├── lib.sh              # portable primitives (log, stow, shell/fisher helpers)
│   ├── registry.sh         # package DSL parser + resolver (registry_install)
│   ├── runner.sh           # step-manifest executor (prompt/--yes/reboot/summary)
│   ├── doctor.sh           # health checks; clean.sh unlinks configs
│   └── adapters/           # per-OS seam: arch.sh (pacman/systemd), macos.sh (brew/dscl)
│
├── profiles/               # ordered steps + stow/theme manifests, per platform
│   ├── linux-hyprland/     # full Arch + Hyprland desktop (default on Arch)
│   │   ├── profile.sh      # PROFILE_STOW/PROFILE_THEME + profile_steps()
│   │   └── steps/          # 00-preflight ... 13-dms (moved from old scripts/)
│   ├── macos/              # macOS CLI + terminal + theme (Homebrew)
│   └── server/             # headless Arch CLI skeleton
│
├── tools/                  # custom binaries (Linux)
│   └── bin/                # pre-built binaries from external repos
│       └── arche-legion    # Lenovo Vantage replacement
│
├── system/                 # system configs (/etc/) — symlinked by the arch adapter
│   ├── etc/
│   └── usr/local/bin/
│
└── stow/                   # behavior configs — symlinked via GNU Stow
    ├── fish/               # shell config (D018 — restored from D003)
    ├── kitty/              # terminal behavior
    ├── starship/           # prompt config
    ├── mpv/                # media player
    ├── hypr/               # Hyprland compositor (D023 — restored)
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
`theming/engine.sh` renders all templates and reloads affected services; the
portable theme functions live in `theming/theme-lib.sh`, shared by the engine and
`core/lib.sh`. nvim is excluded — it uses catppuccin/nvim plugin directly.
The dms desktop shell is themed by `theming/templates/dms/_emit.sh`, which
renders `/opt/arche/run/dms-theme.json` from the active theme (D032).

## Package Management

Each `packages/*.reg` file is a **tool DSL** — one tool per line mapping a
logical name to a per-platform provider and install kind:

```
tool ripgrep  arch=pacman:ripgrep     macos=brew:ripgrep
tool gh       arch=pacman:github-cli  macos=brew:gh        # name differs per OS
tool mpv      arch=pacman:mpv         macos=brew:mpv       # never a cask
```

`core/registry.sh` parses these; steps call `registry_install <platform>
<group>`, which batches by kind and dispatches to the adapter's `pkg_backend`
(pacman/paru on Arch, brew formula/cask on macOS). This one source of truth
across platforms is what prevents provider drift like the deprecated `cask mpv`.
Steps never call `pacman`/`paru`/`brew` directly. Removal is always manual
(`paru -Rns` on Arch). A `tests/` drift-guard lint enforces well-formed lines,
no duplicate tools, mpv-never-a-cask, and no tealdeer/tldr conflict.

## Stow Convention

All stow packages live under `stow/`. Each package mirrors the home directory
structure it targets:

```
stow/fish/.config/fish/config.fish →  ~/.config/fish/config.fish
stow/mpv/.config/mpv/mpv.conf      →  ~/.config/mpv/mpv.conf
```

The `stow_pkg` function in `core/lib.sh` symlinks a package into `$HOME`,
cleaning broken links and backing up real files that would conflict (suffix
`.pre-stow`), so it is safe to re-run. Its core is:

```bash
stow -d "$ARCHE/stow" -t "$HOME" --no-folding "$pkg"
```

## Bootstrap Flow

`bootstrap.sh` is one entrypoint with subcommands (`install` default, `doctor
[--repair]`, `clean [--system|--packages]`) plus `--yes` / `--profile NAME` /
`--only ID`. It auto-selects the profile by platform (arch -> linux-hyprland,
macos -> macos), re-execs under a modern bash if present, loads the profile, and
hands its ordered step list to `core/runner.sh`. Each step is independently
runnable (`bash profiles/linux-hyprland/steps/05-hyprland.sh`) and prompts
before running (y/N/a for all, unless `--yes`); the runner captures exit codes
and prints a final summary table.

Assumes: repo cloned, user has sudo (on Linux).
Does not: clone repo, configure SSH, set up secrets.

## System Stack (linux-hyprland profile)

| Layer        | Tool                                                   |
|--------------|--------------------------------------------------------|
| OS           | Arch Linux (btrfs, systemd-boot with UKIs)             |
| Pre-boot UI  | Plymouth + `arche` theme, TPM2+PIN via sd-encrypt (D024)|
| Compositor   | Hyprland (Wayland) via uwsm (D023)                     |
| Greeter      | SDDM, default Breeze theme (D023)                      |
| Shell / panel| DankMaterialShell (dms) — bar + control-center (D032)  |
| Notifications| dms (owns org.freedesktop.Notifications) (D032)        |
| OSD          | dms (D032)                                             |
| Launcher     | dms spotlight, bound via `dms ipc call` (D032)         |
| Lock / idle  | hyprlock / hypridle                                    |
| Wallpaper    | awww (swww successor — D026)                           |
| Shell        | fish + atuin + fisher + starship (D018)                |
| Terminal     | Kitty                                                  |
| Editor       | Neovim (LazyVim)                                       |
| GPU          | NVIDIA open-dkms (RTX 4060 Laptop)                     |
| Audio        | PipeWire full stack                                    |
| Theme        | Ember (warm amber on deep charcoal)                    |
