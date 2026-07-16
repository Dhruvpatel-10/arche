# packages/ — Package Registry (tool DSL)

Data-only `*.reg` files declaring what to install, across platforms. No logic,
no functions, no side effects. This is the single source of truth for every
package on every platform, so a per-platform provider can never drift silently
again (this is what let the deprecated `cask mpv` slip in).

## Format — the tool DSL

One tool per line:

```
tool <name> <platform>=<kind>:<pkg> [<platform>=<kind>:<pkg> ...]

  platforms : arch, macos
  kinds     : arch  -> pacman | aur
              macos -> brew | cask

  tool mpv    arch=pacman:mpv         macos=brew:mpv       # never a cask
  tool gh     arch=pacman:github-cli  macos=brew:gh        # name differs per OS
  tool paru   arch=aur:paru
  tool cuda   arch=pacman:cuda                             # arch-only, no macos token
```

Omit a platform where the tool does not exist there. `#` starts a comment.
The logical `<name>` lets a tool differ per platform (`github-cli` vs `gh`) while
callers reference one name. `core/registry.sh` parses these.

## Rules

1. Each file is a list of `tool` lines only — no bash, no arrays, no side effects
2. No install commands — steps call `registry_install <platform> <group>` (the
   `<group>` is the `.reg` basename); `core/registry.sh` batches by kind and
   dispatches to the adapter's `pkg_backend`
3. Every tool gets an inline comment when the name or channel is non-obvious
4. AUR packages use `arch=aur:` and go through `paru` (adapter) — never `yay`
5. Homebrew: use `macos=brew:` (formula) by default; `macos=cask:` only when the
   tool genuinely has no formula (e.g. ghostty). Never a cask for mpv.
6. Removal is always manual: `paru -Rns <pkg>` (never bare `-R`)
7. Before adding an AUR package, flag it and show the PKGBUILD source URL

## Drift-guard lint (tests/)

`just test` runs a registry lint that fails CI on: any malformed `.reg` line, any
duplicate tool name, mpv declared as a cask, and tealdeer/tldr both present
(they collide on `/usr/bin/tldr`). The install gate (`just gate`) also re-parses
every `.reg` before a run starts.

## File → Step Mapping (linux-hyprland)

| File | Step | Purpose |
|------|------|---------|
| `base.reg` | `steps/01-base.sh` | Core CLI tools, modern replacements, system essentials |
| `security.reg` | `steps/02-security.sh` | Firewall, SSH, sandboxing |
| `gpu-nvidia.reg` | `steps/03-gpu.sh` | NVIDIA open kernel module, CUDA, VA-API |
| `audio.reg` | `steps/04-audio.sh` | Full PipeWire stack, TUI mixer |
| `hyprland.reg` | `steps/05-hyprland.sh` | Hyprland, portals, SDDM, Wayland utils |
| `shell.reg` | `steps/06-shell.sh` | Fish, Atuin, Starship, Kitty, tmux |
| `dms.reg` | `steps/13-dms.sh` | DankMaterialShell + Quickshell + NetworkManager |
| `runtimes.reg` | `steps/08-runtimes.sh` | Rust, Go, cmake, clang, JDK17, Android SDK |
| `apps.reg` | `steps/09-apps.sh` | Neovim, Vivaldi, Nautilus, mpv, Docker, Bluetooth |
| `appearance.reg` | `steps/11-appearance.sh` | Fonts, icons, nwg-look |
| `boot.reg` | `steps/12-boot.sh` | TPM2 unlock tooling (no graphical splash) |
| `macos.reg` | `profiles/macos` | macOS-only tools (coreutils, gettext, bash, fnm, uv, duti, ghostty) |

Steps live under `profiles/linux-hyprland/steps/`. `base.reg` and `shell.reg`
are shared: the `server` profile also installs them, and the `macos` profile
installs every tool with a `macos=` token across all groups.

## Package Inventory

Each group is now a `.reg` file. Many `base`/`shell`/`apps` tools carry a
`macos=brew:` token too (they are shared with the macOS and server profiles);
Arch-only tools have no `macos=` token. Counts below are the Arch (pacman/AUR)
side.

### base.reg — Core System (pacman: 24)
- **Build tools:** base-devel, git, stow, just, curl, wget, unzip, p7zip
- **Modern CLI:** eza (ls), bat (cat), ripgrep (grep), fd (find), fzf, zoxide (cd), dust (du), btop (top), nvtop (GPU), jq, yq, tealdeer (tldr), gum, lazygit, lazydocker
- **System:** linux-headers, man-db, man-pages, amd-ucode, reflector, snapper
- **Wayland CLI:** wl-clipboard
- **Note:** `shellcheck` installed as static binary by `01-base.sh` (pacman version
  pulls 56 Haskell packages for a 4 MB tool — upstream ships a static binary).

### security.reg — Security (pacman: 5)
- ufw, openssh, tailscale, firejail, fail2ban

### gpu-nvidia.reg — NVIDIA GPU (pacman: 7)
- nvidia-open-dkms, nvidia-utils, nvidia-settings, lib32-nvidia-utils
- libva-nvidia-driver (VA-API), egl-wayland, cuda

### audio.reg — Audio (pacman: 11)
- **PipeWire stack:** pipewire, pipewire-alsa, pipewire-jack, pipewire-pulse, wireplumber
- **Extras:** gst-plugin-pipewire, alsa-utils, pamixer, wiremix (TUI mixer), playerctl, sof-firmware

### hyprland.reg — Hyprland Desktop (pacman: ~17, AUR: 1)
- **Compositor / session:** hyprland, hyprlock, hypridle, hyprpicker, hyprsunset, hyprpolkitagent, uwsm, xdg-desktop-portal-hyprland, xdg-desktop-portal-gtk (Settings + FileChooser — brings dark-mode signal to Electron/Chromium/Vivaldi)
- **Login manager:** sddm, qt6-svg, qt5-wayland, qt6-wayland (default Breeze theme — see D023)
- **Wayland utils:** awww (wallpaper — swww successor), grim, slurp, satty (screenshots), cliphist (clipboard)
- **Input / backlight:** brightnessctl, wev
- **Launcher:** dms spotlight (Super+Space → `dms ipc call spotlight toggle`); rofi removed in D031, dms adopted in D032
- **AUR:** hyprland-preview-share-picker-git (xdph's `custom_picker_binary` with live previews — D028 reverses D027)

### dms.reg — DankMaterialShell (pacman: 3)
- **Shell:** dms-shell, dms-shell-hyprland (official `extra` repo)
- **Service backend:** networkmanager (dms talks to it over D-Bus)
- **Note:** quickshell is not a direct entry; it comes in transitively via dms-shell.
- **Note:** Shell source is package-managed at `/usr/share/quickshell/dms/`,
  not in the repo. Set up by `steps/13-dms.sh`. See D032 (supersedes D029's panel).

### shell.reg — Shell (pacman: 5)
- fish, atuin, starship, kitty, tmux (fish/atuin/starship/tmux also `macos=brew:`; kitty is Arch-only, macOS uses Ghostty)
- fisher (fish plugin manager) is installed from upstream curl by `steps/06-shell.sh` — not from AUR. See D018.

### runtimes.reg — Dev Runtimes (pacman: 7, AUR: 4)
- rust, go, cmake, clang, gdb
- jdk17-openjdk, android-udev (Android / React Native prerequisites)
- **AUR:** android-sdk, android-sdk-platform-tools, android-sdk-build-tools, android-platform — installs to `/opt/android-sdk`. `steps/08-runtimes.sh` adds every human user to the `android-sdk` group and pins default JDK to 17. PATH/`ANDROID_HOME` set by `stow/fish/.config/fish/conf.d/android.fish`.
- **Note:** fnm (Node) and Bun install via their own scripts in `steps/08-runtimes.sh`, not pacman. On macOS fnm/uv come from `macos.reg` (brew).

### apps.reg — Applications (pacman: ~35)
- **Editor:** neovim (also `macos=brew:`)
- **Browser:** vivaldi
- **Files:** nautilus, syncthing
- **Media:** mpv (`macos=brew:mpv` — NEVER cask), imagemagick, papers (PDF/EPUB, libadwaita), loupe (images, libadwaita), kdenlive (video)
- **Recording:** obs-studio, v4l2loopback-dkms
- **Utils:** fastfetch, glow, aria2, github-cli (`macos=brew:gh`), plocate, tree-sitter-cli (`macos=brew:tree-sitter`) — tldr command comes from tealdeer in `base.reg`
- **Remote desktop:** remmina, freerdp (xfreerdp3 backend), gnome-keyring, seahorse
- **Desktop:** qbittorrent, kdeconnect, kio-extras, gvfs-mtp, gvfs-gphoto2
- **Bluetooth:** bluez, bluez-utils, bluetui (TUI pairing — Super+Ctrl+B)
- **Docker:** docker, docker-buildx, docker-compose, rootlesskit, slirp4netns
  (rootless setuptool is no longer packaged as of Docker 29 — fetch from
  upstream if rootless is needed)

### appearance.reg — Appearance (pacman: 9)
- **Fonts:** ttf-ibm-plex (UI sans), ttf-meslo-nerd (primary mono), ttf-jetbrains-mono-nerd (fallback), ttf-lato (Slack UI), noto-fonts (web fallback), noto-fonts-emoji
- **Icons:** papirus-icon-theme
- **GTK themes:** gnome-themes-extra (provides Adwaita-dark GTK3 theme files — not in base gtk3)
- **GTK tool:** nwg-look (GTK3/4 configurator — there is no KDE to set GTK theming on Hyprland, D023)
- **Qt:** nothing. We dropped all Qt apps (okular → papers, gwenview → loupe) so no Qt theming is needed. If a Qt app is added later, install qt6ct + set `QT_QPA_PLATFORMTHEME` then.

### boot.reg — TPM2 unlock (pacman: 1)
- **TPM2:** tpm2-tools (systemd-cryptenroll backend; tpm2-tss is already pulled by systemd)
- **Note:** this branch boots to a plain kernel TTY. There is no Plymouth splash.

### macos.reg — macOS-only tools (brew/cask)
- **GNU userland (for the theme engine):** coreutils, gettext (envsubst)
- **Modern bash:** bash — the redesign re-execs bootstrap under it (macOS ships 3.2)
- **Runtimes:** fnm (Node), uv (Python) — curl-installed on Linux, brew here
- **Utilities:** duti (set default apps by UTI), ghostty (`macos=cask:ghostty` — no formula)

## Totals

- **Pacman:** ~90 packages across 11 Arch-facing `.reg` files
- **AUR:** 5 packages (hyprland-preview-share-picker-git; android-sdk, -platform-tools, -build-tools, android-platform)
- **Homebrew:** the shared tools with a `macos=` token, plus `macos.reg`

## Not Managed Here

These are installed outside the package registry:
- **arche-denoise** — custom binary in `tools/bin/`, deployed via systemd service
- **arche-legion** — custom binary in `tools/bin/`, deployed to `~/.local/bin/arche/`
- **dms shell source** — package-managed QML at `/usr/share/quickshell/dms/`
  (dms-shell pkg); set up by `steps/13-dms.sh` (D032; supersedes D029's panel)
- **fisher** — fish plugin manager, installed from upstream curl into `~/.config/fish/functions/fisher.fish` by `steps/06-shell.sh` (D018)
- **fnm** — Node version manager (curl script in `steps/08-runtimes.sh` on Arch; `macos.reg` on macOS)
- **Bun** — JS runtime (official curl script in `steps/08-runtimes.sh`)
- **shellcheck** — static binary from upstream GitHub release, installed to `/usr/local/bin/shellcheck` by `steps/01-base.sh` (SHA256-pinned)
