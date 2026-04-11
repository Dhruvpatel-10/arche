# packages/ — Package Registry

Data-only files declaring what to install. No logic, no functions, no side effects.

## Rules

1. Each file exports exactly two arrays: `PACMAN_PKGS=()` and `AUR_PKGS=()`
2. No install commands — `lib.sh:install_group` handles installation
3. Every package gets an inline comment explaining what it is
4. AUR packages go through `paru` — never `yay`
5. Removal is always manual: `paru -Rns <pkg>` (never bare `-R`)
6. Before adding an AUR package, flag it and show the PKGBUILD source URL

## File → Script Mapping

| File | Script | Purpose |
|------|--------|---------|
| `base.sh` | `01-base.sh` | Core CLI tools, modern replacements, system essentials |
| `security.sh` | `02-security.sh` | Firewall, SSH, sandboxing, USB security |
| `gpu-nvidia.sh` | `03-gpu.sh` | NVIDIA open kernel module, CUDA, VA-API |
| `audio.sh` | `04-audio.sh` | Full PipeWire stack, TUI mixer |
| `hyprland.sh` | `05-hyprland.sh` | Compositor, portals, Wayland utils, launcher |
| `shell.sh` | `06-shell.sh` | Fish, Starship, Kitty, tmux |
| `bar.sh` | `07-bar.sh` | Waybar |
| `notifications.sh` | `08-notifications.sh` | Mako |
| `runtimes.sh` | `09-runtimes.sh` | Rust, Go, cmake, clang, Bun |
| `apps.sh` | `10-apps.sh` | Neovim, Vivaldi, Nemo, mpv, Docker, Bluetooth |
| `appearance.sh` | `12-appearance.sh` | Fonts, icons, cursors, GTK/Qt theming |

## Package Inventory

### base.sh — Core System (pacman: 24)
- **Build tools:** base-devel, git, stow, just, curl, wget, unzip, p7zip
- **Modern CLI:** eza (ls), bat (cat), ripgrep (grep), fd (find), fzf, zoxide (cd), dust (du), btop (top), nvtop (GPU), jq, yq, tealdeer (tldr), gum, lazygit, lazydocker
- **System:** linux-headers, man-db, man-pages, amd-ucode, reflector, snapper, shellcheck

### security.sh — Security (pacman: 7)
- ufw, openssh, tailscale, gnome-keyring, firejail, usbguard, fail2ban

### gpu-nvidia.sh — NVIDIA GPU (pacman: 7)
- nvidia-open-dkms, nvidia-utils, nvidia-settings, lib32-nvidia-utils
- libva-nvidia-driver (VA-API), egl-wayland, cuda

### audio.sh — Audio (pacman: 8)
- **PipeWire stack:** pipewire, pipewire-alsa, pipewire-jack, pipewire-pulse, wireplumber
- **Extras:** gst-plugin-pipewire, alsa-utils, pamixer, wiremix (TUI mixer), playerctl, sof-firmware

### hyprland.sh — Compositor (pacman: 17, AUR: 1)
- **Core:** hyprland, hyprlock, hypridle, hyprpicker, hyprsunset, uwsm
- **Portals:** xdg-desktop-portal-hyprland
- **Login:** SDDM (X11 greeter) + vendored eucalyptus-drop theme (see D013)
- **Wayland utils:** hyprpaper, grim, slurp, satty, wl-clipboard, cliphist, wev, brightnessctl
- **Launcher:** rofi-wayland
- **Qt:** qt5-wayland, qt6-wayland, hyprpolkitagent
- **AUR:** syshud (OSD overlay)

### shell.sh — Shell (pacman: 6)
- bash, bash-completion, atuin, starship, kitty, tmux
- ble.sh, bash-preexec, carapace are **vendored** (see D016), not installed from AUR

### bar.sh — Status Bar (pacman: 1)
- waybar

### notifications.sh — Notifications (pacman: 1)
- mako

### runtimes.sh — Dev Runtimes (pacman: 5)
- rust, go, cmake, clang, gdb
- **Note:** fnm (Node) and Bun install via their own scripts in `09-runtimes.sh`, not pacman

### apps.sh — Applications (pacman: 20)
- **Editor:** neovim
- **Browser:** vivaldi
- **Files:** nemo, syncthing
- **Media:** mpv, imv, imagemagick, ffmpegthumbnailer
- **Utils:** fastfetch, glow, aria2, tldr, github-cli, plocate, tree-sitter-cli
- **Desktop:** qbittorrent, zathura, zathura-pdf-mupdf
- **Bluetooth:** bluez, bluez-utils
- **Docker:** docker, docker-rootless-extras, docker-buildx, docker-compose

### appearance.sh — Appearance (pacman: 5)
- **Fonts:** ttf-ibm-plex (UI sans), ttf-meslo-nerd (primary mono), ttf-jetbrains-mono-nerd (fallback), noto-fonts-emoji
- **Icons:** papirus-icon-theme
- **Theming:** nwg-look

## Totals

- **Pacman:** ~99 packages across 11 files
- **AUR:** 1 package (syshud)

## Not Managed Here

These are installed outside the package registry:
- **arche-denoise** — custom binary in `tools/bin/`, deployed via systemd service
- **arche-greeter** — retired; replaced by SDDM + SilentSDDM (see D013, which reverses D010)
- **sddm-silent** (SilentSDDM theme) — vendored under `vendor/sddm-silent/` (not a package), installed via `cp` by `05-hyprland.sh`
- **arche-legion** — custom binary in `tools/bin/`, deployed to `~/.local/bin/arche/`
- **ble.sh** — vendored under `vendor/blesh/`, sourced directly from `/opt/arche/vendor/blesh/ble.sh` (D016)
- **bash-preexec** — vendored under `vendor/bash-preexec/`, sourced directly (D016)
- **carapace** — vendored binary at `tools/bin/carapace`, symlinked to `~/.local/bin/arche/carapace` by `06-shell.sh` (D016)
- **fnm** — Node version manager (curl script in `09-runtimes.sh`)
- **Bun** — JS runtime (official curl script in `09-runtimes.sh`)
- **LADSPA plugin** — removed; arche-denoise is now a single binary
