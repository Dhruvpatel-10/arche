# Component Status

Tracks what's built, what's planned, and what's blocked.

Last updated: 2026-04-18

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

| Package                              | Status  | Notes                                           |
|--------------------------------------|---------|-------------------------------------------------|
| `fish`                               | Done    | config.fish, conf.d/, functions/, abbreviations, fisher plugins — D018 |
| `kitty`                              | Done    | Terminal config + theme template                |
| `starship`                           | Done    | Prompt config                                   |
| `mpv`                                | Done    | Media player                                    |
| `hypr`                               | Done    | Hyprland compositor config (D023 — restored)    |
| `rofi`                               | Done    | Spotlight-style app launcher (D023 — restored)  |
| `cliphist`                           | Done    | Clipboard history (D023 — restored)             |
| `hyprland-preview-share-picker`      | Done    | Screen-share source picker (D023 — restored)    |
| `arche-scripts`                      | Done    | User scripts: wallpaper, popup, powermenu, etc. |
| `nvim`                               | Done    | LazyVim + catppuccin                            |
| `gtk`                                | Done    | Fully templated (no stow — all visual)          |
| `btop`                               | Done    | System monitor config                           |
| `tmux`                               | Done    | Terminal multiplexer config                     |
| `kvantum`                            | Done    | Qt style engine (Ember theme)                   |
| `qt6ct`                              | Done    | Qt6 color palette (config is templated)         |
| `pipewire`                           | Done    | Audio daemon config                             |
| `wireplumber`                        | Done    | Audio session manager config                    |
| `vivaldi`                            | Done    | Browser flags                                   |
| `paru`                               | Done    | AUR helper security config                      |
| ~~`kde`~~                            | Removed | Replaced by Hyprland + Quickshell (D023)        |
| ~~`waybar`~~                         | Removed | Replaced by Quickshell panel (D023)             |
| ~~`mako`~~                           | Removed | Replaced by Quickshell toasts (D023)            |
| ~~`swayosd` / `syshud`~~             | Removed | Replaced by Quickshell OSD (D023)               |
| ~~`zathura`~~                        | Removed | Replaced by okular as PDF viewer (D023)         |

## Package Registry

| File                       | Status | Notes                                          |
|----------------------------|--------|------------------------------------------------|
| `packages/base.sh`         | Done   |                                                |
| `packages/security.sh`     | Done   |                                                |
| `packages/gpu-nvidia.sh`   | Done   |                                                |
| `packages/audio.sh`        | Done   |                                                |
| `packages/hyprland.sh`     | Done   | D023 — compositor, utils, SDDM, rofi           |
| `packages/shell.sh`        | Done   |                                                |
| `packages/panel.sh`        | Done   | D023 — quickshell + nm backend                 |
| `packages/runtimes.sh`     | Done   |                                                |
| `packages/apps.sh`         | Done   | D023 — dolphin → nautilus; okular/gwenview kept |
| `packages/appearance.sh`   | Done   | D023 — nwg-look for GTK theming                |
| `packages/boot.sh`         | Done   | D024 — plymouth + tpm2-tools                   |

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
| `templates/hyprland-preview-share-picker/style.css.tmpl` | `~/.config/hyprland-preview-share-picker/style.css` | Done |
| `templates/kitty/fonts.conf.tmpl`                     | `~/.config/kitty/fonts.conf`                     | Done   |
| `templates/kitty/theme.conf.tmpl`                     | `~/.config/kitty/theme.conf`                     | Done   |
| `templates/legion/colors.toml.tmpl`                   | `~/.config/legion/colors.toml`                   | Done   |
| `templates/mpv/font-opts.conf.tmpl`                   | `~/.config/mpv/font-opts.conf`                   | Done   |
| `templates/qt6ct/qt6ct.conf.tmpl`                     | `~/.config/qt6ct/qt6ct.conf`                     | Done   |
| `templates/rofi/theme.rasi.tmpl`                      | `~/.config/rofi/theme.rasi`                      | Done   |
| `templates/starship/starship.toml.tmpl`               | `~/.config/starship/starship.toml`               | Done   |
| `templates/tmux/colors.conf.tmpl`                     | `~/.config/tmux/colors.conf`                     | Done   |
| ~~`templates/kde/*`~~                                 | —                                                | Removed (D023) |
| ~~`templates/waybar/style.css.tmpl`~~                 | —                                                | Removed (D021/D023) |
| ~~`templates/mako/config.tmpl`~~                      | —                                                | Removed (D021/D023) |
| ~~`templates/zathura/zathurarc-colors.tmpl`~~         | —                                                | Removed (D023) |

## Tools

| Binary          | Source                          | Deploy                             | Status |
|-----------------|---------------------------------|------------------------------------|--------|
| `arche-legion`  | `tools/bin/` (pre-built)        | `~/.local/bin/arche/` (symlink)    | Done   |

## External Shell

| Repo         | Clone location                     | Symlink target          | Status |
|--------------|------------------------------------|-------------------------|--------|
| `arche-shell` (Dhruvpatel-10/quickshell) | `~/projects/system/arche-shell/` | `~/.config/quickshell/` | Done (D023) |

## System Configs

| File                                    | Target                          | Status |
|-----------------------------------------|---------------------------------|--------|
| `system/etc/pacman.conf`                | `/etc/pacman.conf`              | Done   |
| `system/etc/pacman.d/hooks/00-snapper-pre.hook`  | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/95-boot-cleanup.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/etc/pacman.d/hooks/zz-snapper-post.hook` | `/etc/pacman.d/hooks/` | Done   |
| `system/usr/local/bin/boot-cleanup`     | `/usr/local/bin/boot-cleanup`   | Done   |
| `system/usr/local/bin/snapper-pacman`   | `/usr/local/bin/snapper-pacman` | Done   |
| `system/usr/local/bin/usb-inspect`      | `/usr/local/bin/usb-inspect`    | Done   |
| `system/etc/snapper/configs/root`       | `/etc/snapper/configs/root`     | Done   |
| `system/etc/sddm.conf.d/10-arche.conf`  | `/etc/sddm.conf.d/10-arche.conf`| Done (D023) |
| `system/etc/systemd/resolved.conf`      | `/etc/systemd/resolved.conf`    | Done   |
| `system/etc/sysctl.d/99-arche-hardening.conf` | `/etc/sysctl.d/`          | Done   |
| `system/etc/systemd/logind.conf.d/99-arche.conf` | `/etc/systemd/logind.conf.d/` | Done |
| `system/etc/plymouth/plymouthd.conf`     | `/etc/plymouth/plymouthd.conf`  | Done (D024) |
| `system/etc/mkinitcpio.conf.d/arche.conf`| `/etc/mkinitcpio.conf.d/arche.conf` | Done (D024) |
| `system/etc/mkinitcpio.d/linux.preset`   | `/etc/mkinitcpio.d/linux.preset`| Done (D024) |
| `system/etc/kernel/cmdline`              | `/etc/kernel/cmdline`           | Done (D024) |

## Scripts

| Script                         | Status |
|--------------------------------|--------|
| `scripts/00-preflight.sh`      | Done   |
| `scripts/01-base.sh`           | Done   |
| `scripts/02-security.sh`       | Done   |
| `scripts/03-gpu.sh`            | Done   |
| `scripts/04-audio.sh`          | Done   |
| `scripts/05-hyprland.sh`       | Done (D023) |
| `scripts/06-shell.sh`          | Done   |
| `scripts/07-panel.sh`          | Done (D023) |
| `scripts/08-runtimes.sh`       | Done   |
| `scripts/09-apps.sh`           | Done   |
| `scripts/10-stow.sh`           | Done   |
| `scripts/11-appearance.sh`     | Done   |
| `scripts/12-boot.sh`           | Done (D024) |
| `helpers/tpm2-enroll.sh`       | Done (D024) |

## Known Issues

| ID  | Issue                                         | Priority | Status  |
|-----|-----------------------------------------------|----------|---------|
| G4  | MPV shaders present but not activated         | Low      | Open    |
| J8  | Orphan packages not cleaned                   | Low      | Open    |
| T1  | Qt6ct Ember.conf has hardcoded colors (needs template) | Medium | Open |
| T2  | Kvantum Ember.kvconfig has hardcoded colors (needs template) | Medium | Open |
| T3  | CSS templates hardcode font-size/border-radius instead of using theme vars | Low | Open |
| Q1  | Quickshell theme values duplicate schema.sh (should be rendered from templates/active eventually — D023 follow-up) | Medium | Open |
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
