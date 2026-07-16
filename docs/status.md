# Component Status

Tracks what's built, what's planned, and what's blocked.

Last updated: 2026-07-16

## Infrastructure

Reorganized into a shared core + platform profiles + package DSL (D033).

| Component            | Status  | Notes                                            |
|----------------------|---------|--------------------------------------------------|
| `core/lib.sh`        | Done    | Portable primitives — every step sources this    |
| `core/registry.sh`   | Done    | Package DSL parser + resolver (registry_install) |
| `core/runner.sh`     | Done    | Step-manifest executor (prompt/--yes/reboot)     |
| `core/doctor.sh`     | Done    | `bootstrap.sh doctor [--repair]`                 |
| `core/clean.sh`      | Done    | `bootstrap.sh clean [--system|--packages]`       |
| `core/adapters/arch.sh` | Done | pacman/paru, systemd, /etc linking               |
| `core/adapters/macos.sh` | Done | Homebrew formula/cask, dscl, no-op services     |
| `theming/engine.sh`  | Done    | Theme engine: apply/switch/list (unchanged)      |
| `theming/theme-lib.sh` | Done  | Portable theme fns, shared by engine + core      |
| `install.sh`         | Done    | OS-detecting curl installer                      |
| `bootstrap.sh`       | Done    | Single entrypoint (install/doctor/clean)         |
| `Justfile`           | Done    | Day-to-day interface                             |
| `tests/run.sh`       | Done    | Lint/stow/integration + registry drift-guard     |
| `docs/`              | Done    | Architecture, decisions, status, redesign        |
| `theming/themes/schema.sh` | Done | Variable registry — names, types, defaults    |

## Profiles

| Profile          | Status | Notes                                                        |
|------------------|--------|--------------------------------------------------------------|
| `linux-hyprland` | Done   | Full Arch + Hyprland desktop (default on Arch); steps 00–13  |
| `macos`          | Done   | macOS Apple Silicon: CLI, Ghostty, editor, shell, theme      |
| `server`         | Done   | Headless Arch CLI skeleton (base + shell only)               |

## Stow Packages

| Package                              | Status  | Notes                                           |
|--------------------------------------|---------|-------------------------------------------------|
| `fish`                               | Done    | config.fish, conf.d/, functions/, abbreviations, fisher plugins — D018 |
| `kitty`                              | Done    | Terminal config + theme template                |
| `starship`                           | Done    | Prompt config                                   |
| `mpv`                                | Done    | Media player                                    |
| `hypr`                               | Done    | Hyprland compositor config (D023 — restored)    |
| ~~`rofi`~~                           | Removed | Replaced by Quickshell LauncherDialog (D031)    |
| `cliphist`                           | Done    | Clipboard history (D023 — restored)             |
| `hyprland-preview-share-picker`      | Done    | Screen-share source picker — AUR (D028 reverses D027) |
| `arche-scripts`                      | Done    | User scripts: wallpaper, popup, powermenu, etc. |
| `nvim`                               | Done    | LazyVim + catppuccin                            |
| `gtk`                                | Done    | Fully templated (no stow — all visual)          |
| `btop`                               | Done    | System monitor config                           |
| `tmux`                               | Done    | Terminal multiplexer config                     |
| `electron-flags`                     | Done    | Electron Wayland/Ozone flags — flat template |
| ~~`kvantum`~~                        | Removed | Qt style engine dropped — we no longer use any Qt apps |
| ~~`qt5ct`/`qt6ct`/`kdeglobals`~~     | Removed | Qt theming dropped entirely — we replaced all Qt apps with GTK4/libadwaita equivalents (okular → papers, gwenview → loupe) |
| `pipewire`                           | Done    | Audio daemon config                             |
| `wireplumber`                        | Done    | Audio session manager config                    |
| `vivaldi`                            | Done    | Browser flags                                   |
| `paru`                               | Done    | AUR helper security config                      |
| ~~`kde`~~                            | Removed | Replaced by Hyprland + Quickshell (D023)        |
| ~~`waybar`~~                         | Removed | Replaced by Quickshell panel (D023)             |
| ~~`mako`~~                           | Removed | Replaced by Quickshell toasts (D023)            |
| ~~`swayosd` / `syshud`~~             | Removed | Replaced by Quickshell OSD (D023)               |
| ~~`zathura`~~                        | Removed | Replaced by okular as PDF viewer (D023)         |

## Package Registry (tool DSL, `.reg`)

Migrated from two-array `packages/*.sh` files to the `tool` DSL (D033):
`tool <name> arch=kind:pkg macos=kind:pkg`. Parsed by `core/registry.sh`.

| File                       | Status | Notes                                          |
|----------------------------|--------|------------------------------------------------|
| `packages/base.reg`        | Done   | Shared with macos + server profiles            |
| `packages/security.reg`    | Done   |                                                |
| `packages/gpu-nvidia.reg`  | Done   |                                                |
| `packages/audio.reg`       | Done   |                                                |
| `packages/hyprland.reg`    | Done   | D023 — compositor, utils, SDDM (rofi removed D031) |
| `packages/shell.reg`       | Done   | Shared with macos + server profiles            |
| `packages/dms.reg`         | Done   | D032 — dms-shell + quickshell + nm             |
| `packages/runtimes.reg`    | Done   |                                                |
| `packages/apps.reg`        | Done   | D023 — dolphin → nautilus; okular/gwenview replaced |
| `packages/appearance.reg`  | Done   | D023 — nwg-look for GTK theming                |
| `packages/boot.reg`        | Done   | D024 — tpm2-tools                              |
| `packages/macos.reg`       | Done   | D033 — macOS-only brew/cask (replaces Brewfile) |

## Templates

| Template                                              | Renders to                                       | Status |
|-------------------------------------------------------|--------------------------------------------------|--------|
| `templates/btop/arche.theme.tmpl`                     | `~/.config/btop/arche.theme`                     | Done   |
| `templates/fish/conf.d/theme.fish.tmpl`               | `~/.config/fish/conf.d/theme.fish`               | Done   |
| `templates/glow/style.json.tmpl`                      | `~/.config/glow/style.json`                      | Done   |
| `templates/gtk-3.0/settings.ini.tmpl`                 | `~/.config/gtk-3.0/settings.ini`                 | Done   |
| `templates/gtk-4.0/gtk.css.tmpl`                      | `~/.config/gtk-4.0/gtk.css`                      | Done   |
| `templates/gtk-4.0/settings.ini.tmpl`                 | `~/.config/gtk-4.0/settings.ini`                 | Done   |
| `templates/hypr/colors.conf.tmpl`                     | `~/.config/hypr/colors.conf`                     | Done   |
| `templates/hypr/envs.conf.tmpl`                       | `~/.config/hypr/envs.conf`                       | Done   |
| `templates/hypr/hyprlock-colors.conf.tmpl`            | `~/.config/hypr/hyprlock-colors.conf`            | Done   |
| `templates/hypr/hyprlock-fonts.conf.tmpl`             | `~/.config/hypr/hyprlock-fonts.conf`             | Done   |
| `templates/hyprland-preview-share-picker/style.css.tmpl` | `~/.config/hyprland-preview-share-picker/style.css` | Done (D028)   |
| `templates/kitty/fonts.conf.tmpl`                     | `~/.config/kitty/fonts.conf`                     | Done   |
| `templates/kitty/theme.conf.tmpl`                     | `~/.config/kitty/theme.conf`                     | Done   |
| `templates/legion/colors.toml.tmpl`                   | `~/.config/legion/colors.toml`                   | Done   |
| `templates/mpv/font-opts.conf.tmpl`                   | `~/.config/mpv/font-opts.conf`                   | Done   |
| `templates/qt6ct/qt6ct.conf.tmpl`                     | `~/.config/qt6ct/qt6ct.conf`                     | Done   |
| ~~`templates/rofi/theme.rasi.tmpl`~~                  | —                                                | Removed (D031) |
| `templates/starship/starship.toml.tmpl`               | `~/.config/starship/starship.toml`               | Done   |
| `templates/tmux/colors.conf.tmpl`                     | `~/.config/tmux/colors.conf`                     | Done   |
| ~~`templates/kde/*`~~                                 | —                                                | Removed (D023) |
| ~~`templates/waybar/style.css.tmpl`~~                 | —                                                | Removed (D021/D023) |
| ~~`templates/mako/config.tmpl`~~                      | —                                                | Removed (D021/D023) |
| ~~`templates/zathura/zathurarc-colors.tmpl`~~         | —                                                | Removed (D023) |

## Tools

| Binary               | Source                          | Deploy                                      | Status |
|----------------------|---------------------------------|---------------------------------------------|--------|
| `arche-legion`       | `tools/bin/` (pre-built)        | `/usr/local/bin/arche/` (symlink via system/)| Done   |
| `arche-denoise`      | `tools/bin/` (pre-built)        | `/usr/local/bin/arche/` (symlink via system/)| Done   |
| `arche-denoise-mic`  | `tools/bin/` (pre-built)        | `/usr/local/bin/arche/` (symlink via system/)| Done   |

## Desktop Shell — dms (D032)

| Source                       | Mechanism                              | Status |
|------------------------------|----------------------------------------|--------|
| `/usr/share/quickshell/dms/` | package-managed (`dms-shell`)          | Done (D032) |
| theme                        | `theming/templates/dms/_emit.sh` → `/opt/arche/run/dms-theme.json` | Done |
| service                      | `dms.service` user unit + resume hook  | Done |

The hand-rolled `/opt/arche/shell/` panel (D029) was removed.

## System Configs

| File                                    | Target                          | Status |
|-----------------------------------------|---------------------------------|--------|
| `system/etc/pacman.conf`                | `/etc/pacman.conf`              | Done   |
| `system/etc/pacman.d/hooks/00-snapper-pre.hook`  | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/95-boot-cleanup.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/zz-snapper-post.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/usr/local/bin/boot-cleanup`     | `/usr/local/bin/boot-cleanup`   | Done   |
| `system/usr/local/bin/snapper-pacman`   | `/usr/local/bin/snapper-pacman` | Done   |
| `system/etc/snapper/configs/root`       | `/etc/snapper/configs/root`     | Done   |
| `system/etc/sddm.conf.d/10-arche.conf`  | `/etc/sddm.conf.d/10-arche.conf`| Done (D023) |
| `system/etc/systemd/resolved.conf`      | `/etc/systemd/resolved.conf`    | Done   |
| `system/etc/sysctl.d/99-arche-hardening.conf` | `/etc/sysctl.d/`          | Done   |
| `system/etc/systemd/logind.conf.d/99-arche.conf` | `/etc/systemd/logind.conf.d/` | Done |
| `system/etc/plymouth/plymouthd.conf`     | `/etc/plymouth/plymouthd.conf`  | Done (D024) |
| `system/etc/mkinitcpio.conf.d/arche.conf`| `/etc/mkinitcpio.conf.d/arche.conf` | Done (D024) |
| `system/etc/mkinitcpio.d/linux.preset`   | `/etc/mkinitcpio.d/linux.preset`| Done (D024) |
| `system/etc/kernel/cmdline`              | `/etc/kernel/cmdline`           | Done (D024) |

## Steps (profiles/linux-hyprland/steps/)

Moved from the old top-level `scripts/` under the linux-hyprland profile (D033);
each now sources `$ARCHE/core/lib.sh` and installs via `registry_install`.

| Step                           | Status |
|--------------------------------|--------|
| `steps/00-preflight.sh`        | Done   |
| `steps/01-base.sh`             | Done   |
| `steps/02-security.sh`         | Done   |
| `steps/03-gpu.sh`              | Done   |
| `steps/04-audio.sh`            | Done   |
| `steps/05-hyprland.sh`         | Done (D023) |
| `steps/06-shell.sh`            | Done   |
| `steps/08-runtimes.sh`         | Done   |
| `steps/09-apps.sh`             | Done   |
| `steps/10-stow.sh`             | Done   |
| `steps/11-appearance.sh`       | Done   |
| `steps/12-boot.sh`             | Done (D024) |
| `steps/13-dms.sh`              | Done (D032) — desktop shell (dms) |
| `steps/dns.sh`                 | Done   |
| `helpers/tpm2-enroll.sh`       | Done (D024) |

## Known Issues

| ID  | Issue                                         | Priority | Status  |
|-----|-----------------------------------------------|----------|---------|
| G4  | MPV shaders present but not activated         | Low      | Open    |
| J8  | Orphan packages not cleaned                   | Low      | Open    |
| ~~T1~~ | ~~Qt6ct Ember.conf has hardcoded colors~~ | — | Resolved — Qt theming removed entirely (no Qt apps left) |
| ~~T2~~ | ~~Kvantum Ember.kvconfig has hardcoded colors~~ | — | Resolved — Qt theming removed entirely |
| T3  | CSS templates hardcode font-size/border-radius instead of using theme vars | Low | Open |
| Q1  | Quickshell theme values duplicate schema.sh (should be rendered from theming/templates/active eventually — D023 follow-up) | Medium | Open |
| B1  | 95-boot-cleanup.hook prunes old kernels but not stale UKIs in /boot/EFI/Linux — D024 follow-up | Low | Open |
| B2  | Plymouth prompt text uses Image.Text fallback (Cantarell) instead of IBM Plex Sans — cosmetic, functional | Low | Open |

## Resolved

| ID  | Issue                    | Resolution                                       |
|-----|--------------------------|--------------------------------------------------|
| X1  | nftables vs ufw conflict | nftables disabled, UFW sole manager              |
| G1  | Hyprland not in dotfiles | Replaced by KDE Plasma (D021), restored (D023)   |
| G10 | sshd not tracked         | Managed by 02-security.sh                        |
| X4  | Legacy config migration  | All configs migrated, clean slate                |
| G3  | MPV sub-font SF Pro      | Changed to IBM Plex Sans                         |
| G5  | watch-later-dir hardcoded| Moved to ~/.local/state/mpv/                     |
| G6  | No GTK/Qt theming        | GTK4 template rendered, stow applied             |
