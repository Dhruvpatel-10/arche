---
name: system-conventions
description: System conventions for stark's Arch Linux arche repo. Auto-load when writing scripts, configs, or any arche work.
user-invocable: false
---

# System Conventions

## The Three-Layer Config Split

Every config file belongs to exactly one layer. Never mix them.

1. **TEMPLATES** — files containing colors, fonts, sizes, spacing.
   Live in `templates/`. Rendered by `scripts/theme.sh` via envsubst.
   Output is gitignored. Examples: style.css.tmpl, config.tmpl, colors.conf.tmpl

2. **STOW PACKAGES** — files containing behavior: keybinds, module lists, rules, logic.
   Live in `<package>/.config/<name>/`. Symlinked via GNU Stow. Committed as-is.
   Examples: hyprland.conf, config.jsonc, .zshrc

3. **GENERATED OUTPUT** — files produced by rendering templates.
   Live in `~/.config/`. Never committed. Never edited directly.

## Four-Step Component Pattern

When adding a new component, always touch all four places:

1. `packages/<name>.sh` — PACMAN_PKGS=() and AUR_PKGS=() arrays, no logic
2. `templates/<name>/` — .tmpl files if the component has visual config (colors/fonts/sizes)
3. `<name>/` — stow package with behavior config
4. `scripts/<nn>-<name>.sh` — numbered script that installs, stows, enables, verifies

Also add the component to bootstrap.sh and Justfile.

## Script Rules

- Shell: bash only (`#!/usr/bin/env bash`), not zsh, not fish
- Every script starts with: `source "$(dirname "$0")/lib.sh"`
- Every script is independently runnable standalone
- Scripts do four things only: install packages, stow config, enable services, verify
- Idempotency: guard every action — check before act, never assume
- Package installs go through `install_group` and `packages/` files, never direct pacman/paru
- No `--noconfirm` anywhere
- Paths: always `$HOME`, never `/home/stark`
- Remove packages: `-Rns` not `-R`
- AUR: paru only, never yay

## lib.sh Primitives

All scripts use only these functions from lib.sh:
- `log_info`, `log_ok`, `log_warn`, `log_err` — logging
- `pkg_install` — pacman install with --needed
- `aur_install` — paru install with --needed + PKGBUILD notice
- `stow_pkg` — stow with conflict check
- `svc_enable` — systemctl enable + start with guard
- `theme_render` — render templates and reload services
- `install_group` — source a packages/ file and install both arrays

## Package Registry

Each `packages/*.sh` file declares two arrays only:
```bash
PACMAN_PKGS=()
AUR_PKGS=()
```
No logic, no functions, no installs. Data only.

## Theme System

- `themes/catppuccin-mocha.sh` exports shell variables (colors, fonts, sizes)
- `themes/active` symlink points to current theme
- `scripts/theme.sh` renders templates via envsubst and reloads services
- nvim handles its own theming — do not route through templates

## Dotfiles Structure

- Repo: `$HOME/arche`
- Manager: GNU Stow 2.4.1
- Stow target: `$HOME` (default)
- Package dir structure: `arche/<package>/.config/<name>/`
- Package dir structure: `arche/stow/<package>/.config/<name>/`
- All stow packages are built and active (see docs/status.md)

## Commit Conventions

feat/fix/chore/docs/refactor — conventional commits always.
Scope = component name (e.g. `feat(mako): ...`).

## Hardware Context

- GPU: NVIDIA RTX 4060 Laptop (nvidia-open-dkms)
- Compositor: Hyprland via uwsm
- Bootloader: Limine (never suggest GRUB or systemd-boot syntax)
- Filesystem: btrfs + snapper

## Ten Rules

1. Never write colors/fonts/sizes into stow package configs — use templates or themes/
2. Never add package installs in numbered scripts directly — use install_group + packages/
3. Never use --noconfirm
4. Never hardcode /home/stark — always $HOME
5. Never commit generated files (style.css, colors.conf, rendered configs)
6. Every new script must be independently runnable
7. Conventional commits with scope = component name
8. If a config file's layer is ambiguous, ask before creating it
9. Before installing any AUR package, flag it and show the PKGBUILD source URL
10. New component = packages/ + templates/ (if visual) + stow package + scripts/

## What Never to Suggest

- GRUB or systemd-boot syntax
- nvm (fnm is active)
- Oh My Zsh (zinit is active)
- pyenv (not installed)
- Hardcoded /home/stark paths
- Secrets in arche repo
