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
| `kde.sh` | `05-kde.sh` | KDE Plasma desktop, portals, plasma-login-manager, Wayland utils |
| `shell.sh` | `06-shell.sh` | Fish, Starship, Kitty, tmux |
| `runtimes.sh` | `07-runtimes.sh` | Rust, Go, cmake, clang, Bun |
| `apps.sh` | `08-apps.sh` | Neovim, Vivaldi, Dolphin, mpv, Docker, Bluetooth |
| `appearance.sh` | `10-appearance.sh` | Fonts, icons, cursors, GTK/Qt theming |

## Package Inventory

### base.sh — Core System (pacman: 24)
- **Build tools:** base-devel, git, stow, just, curl, wget, unzip, p7zip
- **Modern CLI:** eza (ls), bat (cat), ripgrep (grep), fd (find), fzf, zoxide (cd), dust (du), btop (top), nvtop (GPU), jq, yq, tealdeer (tldr), gum, lazygit, lazydocker
- **System:** linux-headers, man-db, man-pages, amd-ucode, reflector, snapper
- **Wayland CLI:** wl-clipboard
- **Note:** `shellcheck` installed as static binary by `01-base.sh` (pacman version
  pulls 56 Haskell packages for a 4 MB tool — upstream ships a static binary).

### security.sh — Security (pacman: 6)
- ufw, openssh, tailscale, firejail, usbguard, fail2ban

### gpu-nvidia.sh — NVIDIA GPU (pacman: 7)
- nvidia-open-dkms, nvidia-utils, nvidia-settings, lib32-nvidia-utils
- libva-nvidia-driver (VA-API), egl-wayland, cuda

### audio.sh — Audio (pacman: 8)
- **PipeWire stack:** pipewire, pipewire-alsa, pipewire-jack, pipewire-pulse, wireplumber
- **Extras:** gst-plugin-pipewire, alsa-utils, pamixer, wiremix (TUI mixer), playerctl, sof-firmware

### kde.sh — KDE Plasma Desktop (pacman: 0)
- **Empty.** KDE is installed at Arch-install time via the `plasma` group
  (archinstall or `pacstrap -K /mnt ... plasma`). As of Plasma 6.6 the group
  pulls in `plasma-login-manager` — the KDE-native replacement for SDDM, see
  D022 — so no separate display-manager package is needed.
- `scripts/05-kde.sh` verifies `plasma-desktop`, `kwin`, `plasma-login-manager`
  are present and fails fast if not — then proceeds to stow KDE configs,
  disable Baloo, apply fonts/icons/cursor/colorscheme.
- Add a package here only if it's arche-specific AND not pulled in by plasma.
- **Hyprland leftovers removed:** `cliphist` (Klipper replaces it),
  `brightnessctl` (Powerdevil handles brightness keys natively).

### shell.sh — Shell (pacman: 5)
- fish, atuin, starship, kitty, tmux
- fisher (fish plugin manager) is installed from upstream curl by `06-shell.sh` — not from AUR. See D018.

### runtimes.sh — Dev Runtimes (pacman: 5)
- rust, go, cmake, clang, gdb
- **Note:** fnm (Node) and Bun install via their own scripts in `07-runtimes.sh`, not pacman

### apps.sh — Applications (pacman: 23)
- **Editor:** neovim
- **Browser:** vivaldi
- **Files:** dolphin, syncthing
- **Media:** mpv, imagemagick, ffmpegthumbs, kdenlive
- **Recording:** obs-studio, v4l2loopback-dkms
- **Utils:** fastfetch, glow, aria2, tldr, github-cli, plocate, tree-sitter-cli
- **Desktop:** qbittorrent, okular, gwenview, kdeconnect
- **Bluetooth:** bluez, bluez-utils
- **Docker:** docker, docker-rootless-extras, docker-buildx, docker-compose

### appearance.sh — Appearance (pacman: 5)
- **Fonts:** ttf-ibm-plex (UI sans), ttf-meslo-nerd (primary mono), ttf-jetbrains-mono-nerd (fallback), noto-fonts-emoji
- **Icons:** papirus-icon-theme
- **Note:** nwg-look removed (was Hyprland-era) — kde-gtk-config (in kde.sh) handles GTK theming

## Totals

- **Pacman:** ~79 packages across 9 files (KDE stack — including plasma-login-manager — assumed present from Arch install)
- **AUR:** 0 packages

## Not Managed Here

These are installed outside the package registry:
- **arche-denoise** — custom binary in `tools/bin/`, deployed via systemd service
- **arche-greeter** — retired; SDDM (D013, D021) then plasma-login-manager (D022) replaced it
- **sddm-silent** (SilentSDDM theme) — obsolete (D021/D022); SDDM itself has been retired in favour of plasma-login-manager
- **arche-legion** — custom binary in `tools/bin/`, deployed to `~/.local/bin/arche/`
- **fisher** — fish plugin manager, installed from upstream curl into `~/.config/fish/functions/fisher.fish` by `06-shell.sh` (D018)
- **fnm** — Node version manager (curl script in `07-runtimes.sh`)
- **Bun** — JS runtime (official curl script in `07-runtimes.sh`)
- **shellcheck** — static binary from upstream GitHub release, installed to `/usr/local/bin/shellcheck` by `01-base.sh` (SHA256-pinned)
- **LADSPA plugin** — removed; arche-denoise is now a single binary
