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
| `hyprland.sh` | `05-hyprland.sh` | Hyprland, portals, SDDM, rofi, Wayland utils |
| `shell.sh` | `06-shell.sh` | Fish, Starship, Kitty, tmux |
| `panel.sh` | `07-panel.sh` | Quickshell + NetworkManager backend |
| `runtimes.sh` | `08-runtimes.sh` | Rust, Go, cmake, clang, Bun |
| `apps.sh` | `09-apps.sh` | Neovim, Vivaldi, Nautilus, mpv, Docker, Bluetooth |
| `appearance.sh` | `11-appearance.sh` | Fonts, icons, nwg-look |
| `boot.sh` | `12-boot.sh` | Plymouth splash, TPM2 tools |

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

### hyprland.sh — Hyprland Desktop (pacman: ~18, AUR: 1)
- **Compositor / session:** hyprland, hyprlock, hypridle, hyprpicker, hyprsunset, hyprpolkitagent, uwsm, xdg-desktop-portal-hyprland
- **Login manager:** sddm, qt6-svg, qt5-wayland, qt6-wayland (default Breeze theme — see D023)
- **Wayland utils:** awww (wallpaper — swww successor), grim, slurp, satty (screenshots), cliphist (clipboard)
- **Input / backlight:** brightnessctl, wev
- **Launcher:** rofi-wayland
- **AUR:** hyprland-preview-share-picker-git (xdph's `custom_picker_binary` with live previews — D028 reverses D027)

### panel.sh — Quickshell Panel (pacman: 2)
- **Shell runtime:** quickshell (QML-based Wayland layer shell)
- **Service backend:** networkmanager (nmcli, used by Quickshell's Net service)
- **Note:** The QML source (arche-shell) is cloned by `07-panel.sh` from
  <https://github.com/Dhruvpatel-10/quickshell>, not installed via pacman.

### shell.sh — Shell (pacman: 5)
- fish, atuin, starship, kitty, tmux
- fisher (fish plugin manager) is installed from upstream curl by `06-shell.sh` — not from AUR. See D018.

### runtimes.sh — Dev Runtimes (pacman: 5)
- rust, go, cmake, clang, gdb
- **Note:** fnm (Node) and Bun install via their own scripts in `08-runtimes.sh`, not pacman

### apps.sh — Applications (pacman: ~22)
- **Editor:** neovim
- **Browser:** vivaldi
- **Files:** nautilus, syncthing
- **Media:** mpv, imagemagick, okular (PDF), gwenview (images), kdenlive (video)
- **Recording:** obs-studio, v4l2loopback-dkms
- **Utils:** fastfetch, glow, aria2, tldr, github-cli, plocate, tree-sitter-cli
- **Desktop:** qbittorrent, kdeconnect
- **Bluetooth:** bluez, bluez-utils
- **Docker:** docker, docker-buildx, docker-compose, rootlesskit, slirp4netns
  (rootless setuptool is no longer packaged as of Docker 29 — fetch from
  upstream if rootless is needed)

### appearance.sh — Appearance (pacman: 6)
- **Fonts:** ttf-ibm-plex (UI sans), ttf-meslo-nerd (primary mono), ttf-jetbrains-mono-nerd (fallback), noto-fonts-emoji
- **Icons:** papirus-icon-theme
- **GTK tool:** nwg-look (GTK3/4 configurator — there is no KDE to set GTK theming on Hyprland, D023)

### boot.sh — Pre-boot UI + TPM2 (pacman: 2)
- **Plymouth:** plymouth (script-module splash — custom `arche` theme lives in `tools/plymouth/arche/`)
- **TPM2:** tpm2-tools (systemd-cryptenroll backend; tpm2-tss is already pulled by systemd)
- **Note:** the Plymouth theme requires `ttf-ibm-plex` (in appearance.sh) and `imagemagick` (in apps.sh) to render the ARCHE wordmark at install time — `12-boot.sh` fails fast if they're missing.

## Totals

- **Pacman:** ~85 packages across 11 files
- **AUR:** 1 package (hyprland-preview-share-picker-git)

## Not Managed Here

These are installed outside the package registry:
- **arche-denoise** — custom binary in `tools/bin/`, deployed via systemd service
- **arche-legion** — custom binary in `tools/bin/`, deployed to `~/.local/bin/arche/`
- **arche-shell** — QML source, cloned from GitHub to `~/projects/system/arche-shell/`
  by `07-panel.sh` (D023); `~/.config/quickshell/` is a symlink to that clone
- **fisher** — fish plugin manager, installed from upstream curl into `~/.config/fish/functions/fisher.fish` by `06-shell.sh` (D018)
- **fnm** — Node version manager (curl script in `08-runtimes.sh`)
- **Bun** — JS runtime (official curl script in `08-runtimes.sh`)
- **shellcheck** — static binary from upstream GitHub release, installed to `/usr/local/bin/shellcheck` by `01-base.sh` (SHA256-pinned)
