# Component Status

Tracks what's built, what's planned, and what's blocked.

Last updated: 2026-04-03

## Infrastructure

| Component          | Status  | Notes                              |
|--------------------|---------|------------------------------------|
| `scripts/lib.sh`   | Done    | Shared primitives for all scripts  |
| `scripts/theme.sh` | Done    | Theme engine: apply/switch/list    |
| `bootstrap.sh`     | Done    | Orchestrator                       |
| `Justfile`         | Done    | Day-to-day interface               |
| `tests/run.sh`     | Done    | Lint/stow/integration test runner  |
| `docs/`            | Done    | Architecture, decisions, status    |
| `themes/schema.sh` | Done    | Variable registry — names, types, defaults |

## Stow Packages

| Package                        | Status  | Notes                                     |
|--------------------------------|---------|--------------------------------------------|
| `bash`                         | Done    | .bashrc, conf.d/, functions/, aliases, abbreviations (ble.sh) — D016 |
| `kitty`                        | Done    | Terminal config + theme template           |
| `starship`                     | Done    | Prompt config                              |
| `mpv`                          | Done    | Media player                               |
| `hypr`                         | Done    | Full Hyprland config                       |
| `waybar`                       | Done    | Status bar config                          |
| `rofi`                         | Done    | App launcher config (Spotlight-style)      |
| `nvim`                         | Done    | LazyVim + catppuccin                       |
| `gtk`                          | Done    | Fully templated (no stow — all visual)     |
| `syshud`                       | Done    | OSD overlay (behavior config + CSS template) |
| `btop`                         | Done    | System monitor config                      |
| `tmux`                         | Done    | Terminal multiplexer config                |
| `kvantum`                      | Done    | Qt style engine (Ember theme)              |
| `qt6ct`                        | Done    | Qt6 color palette (config is templated)    |
| `pipewire`                     | Done    | Audio daemon config                        |
| `wireplumber`                  | Done    | Audio session manager config               |
| `vivaldi`                      | Done    | Browser flags                              |
| `paru`                         | Done    | AUR helper security config                 |
| `hyprland-preview-share-picker`| Done    | Screenshot/share picker UI                 |
| `zathura`                      | Done    | PDF viewer (Ember themed, vim-style)       |

## Package Registry

| File                       | Status |
|----------------------------|--------|
| `packages/base.sh`         | Done   |
| `packages/security.sh`     | Done   |
| `packages/gpu-nvidia.sh`   | Done   |
| `packages/audio.sh`        | Done   |
| `packages/hyprland.sh`     | Done   |
| `packages/shell.sh`        | Done   |
| `packages/bar.sh`          | Done   |
| `packages/notifications.sh`| Done   | mako |
| `packages/runtimes.sh`     | Done   |
| `packages/apps.sh`         | Done   |
| `packages/appearance.sh`   | Done   |

## Templates

| Template                                              | Renders to                                       | Status |
|-------------------------------------------------------|--------------------------------------------------|--------|
| `templates/kitty/theme.conf.tmpl`                     | `~/.config/kitty/theme.conf`                     | Done   |
| `templates/hypr/colors.conf.tmpl`                     | `~/.config/hypr/colors.conf`                     | Done   |
| `templates/hypr/hyprlock-colors.conf.tmpl`            | `~/.config/hypr/hyprlock-colors.conf`            | Done   |
| `templates/waybar/style.css.tmpl`                     | `~/.config/waybar/style.css`                     | Done   |
| `templates/syshud/style.css.tmpl`                     | `~/.config/sys64/hud/style.css`                  | Done   |
| `templates/rofi/theme.rasi.tmpl`                      | `~/.config/rofi/theme.rasi`                      | Done   |
| `templates/gtk-4.0/gtk.css.tmpl`                      | `~/.config/gtk-4.0/gtk.css`                      | Done   |
| `templates/btop/arche.theme.tmpl`                     | `~/.config/btop/arche.theme`                     | Done   |
| `templates/mako/config.tmpl`                          | `~/.config/mako/config`                          | Done   |
| `templates/tmux/colors.conf.tmpl`                     | `~/.config/tmux/colors.conf`                     | Done   |
| `templates/hyprland-preview-share-picker/style.css.tmpl` | `~/.config/hyprland-preview-share-picker/style.css` | Done |
| `templates/zathura/zathurarc-colors.tmpl`                | `~/.config/zathura/zathurarc-colors`                | Done |
| `templates/gtk-3.0/settings.ini.tmpl`                    | `~/.config/gtk-3.0/settings.ini`                    | Done |
| `templates/gtk-4.0/settings.ini.tmpl`                    | `~/.config/gtk-4.0/settings.ini`                    | Done |
| `templates/hypr/envs.conf.tmpl`                          | `~/.config/hypr/envs.conf`                          | Done |
| `templates/hypr/hyprlock-fonts.conf.tmpl`                | `~/.config/hypr/hyprlock-fonts.conf`                | Done |
| `templates/kitty/fonts.conf.tmpl`                        | `~/.config/kitty/fonts.conf`                        | Done |
| `templates/mpv/fonts.conf.tmpl`                          | `~/.config/mpv/fonts.conf`                          | Done |
| `templates/qt6ct/qt6ct.conf.tmpl`                        | `~/.config/qt6ct/qt6ct.conf`                        | Done |

## Tools

| Binary                       | Source                  | Deploy                        | Status |
|------------------------------|-------------------------|-------------------------------|--------|
| `arche-legion`               | `tools/bin/` (pre-built)  | `~/.local/bin/arche/` (symlink) | Done   |
| `sddm-silent`                | `vendor/` (SilentSDDM, glassmorphism) | `/usr/share/sddm/themes/silent/` (cp) | Done |

## System Configs

| File                                    | Target                          | Status |
|-----------------------------------------|---------------------------------|--------|
| `system/etc/pacman.conf`                | `/etc/pacman.conf`              | Done   |
| `system/etc/pacman.d/hooks/00-snapper-pre.hook`  | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/95-boot-cleanup.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/zz-snapper-post.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/usr/local/bin/boot-cleanup`     | `/usr/local/bin/boot-cleanup`   | Done   |
| `system/usr/local/bin/snapper-pacman`   | `/usr/local/bin/snapper-pacman` | Done   |
| `system/usr/local/bin/usb-inspect`     | `/usr/local/bin/usb-inspect`    | Done   |
| `system/etc/snapper/configs/root`        | `/etc/snapper/configs/root`     | Done   |
| `system/etc/sddm.conf.d/10-arche.conf`  | `/etc/sddm.conf.d/10-arche.conf` | Done  |
| `system/etc/systemd/resolved.conf`      | `/etc/systemd/resolved.conf`    | Done   |
| `system/etc/sysctl.d/99-arche-hardening.conf` | `/etc/sysctl.d/`          | Done   |
| `system/etc/systemd/logind.conf.d/99-arche.conf` | `/etc/systemd/logind.conf.d/` | Done |

## Scripts

| Script                         | Status |
|--------------------------------|--------|
| `scripts/00-preflight.sh`      | Done   |
| `scripts/01-base.sh`           | Done   |
| `scripts/02-security.sh`       | Done   |
| `scripts/03-gpu.sh`            | Done   |
| `scripts/04-audio.sh`          | Done   |
| `scripts/05-hyprland.sh`       | Done   |
| `scripts/06-shell.sh`          | Done   |
| `scripts/07-bar.sh`            | Done   |
| `scripts/08-notifications.sh`  | Done   |
| `scripts/09-runtimes.sh`       | Done   |
| `scripts/10-apps.sh`           | Done   |
| `scripts/11-stow.sh`           | Done   |
| `scripts/12-appearance.sh`     | Done   |

## Known Issues

| ID  | Issue                                         | Priority | Status  |
|-----|-----------------------------------------------|----------|---------|
| G4  | MPV shaders present but not activated         | Low      | Open    |
| J8  | Orphan packages not cleaned                   | Low      | Open    |
| T1  | Qt6ct Ember.conf has hardcoded colors (needs template) | Medium | Open |
| T2  | Kvantum Ember.kvconfig has hardcoded colors (needs template) | Medium | Open |
| T3  | CSS templates hardcode font-size/border-radius instead of using theme vars | Low | Open |

## Resolved

| ID  | Issue                    | Resolution                           |
|-----|--------------------------|--------------------------------------|
| X1  | nftables vs ufw conflict | nftables disabled, UFW sole manager  |
| G1  | Hyprland not in dotfiles | Full config in stow/hypr             |
| G10 | sshd not tracked         | Managed by 02-security.sh            |
| X4  | Legacy config migration   | All configs migrated, clean slate    |
| G3  | MPV sub-font SF Pro      | Changed to IBM Plex Sans             |
| G5  | watch-later-dir hardcoded| Moved to ~/.local/state/mpv/         |
| G6  | No GTK/Qt theming        | GTK4 template rendered, stow applied |
