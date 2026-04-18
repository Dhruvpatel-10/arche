# Claude Code — Global Standing Instructions

## Who I Am
- User: stark
- Host: Arch Linux 6.x | Lenovo Legion Pro 5 16ARX8 | RTX 4060 Laptop | AMD Ryzen | Hyprland (Wayland) + Quickshell panel
- Primary interface: Claude Code (terminal, TUI-first)
- Shell: Fish + Atuin (Ctrl-R) + Fisher (plugins) | Prompt: Starship | Terminal: Kitty
- Dotfiles: `/opt/arche` (shared across users), per-user `~/arche` → `/opt/arche` symlink. Managed with GNU Stow 2.4.1. See D014.

## Goal
Clone this repo on a fresh Arch install, run `bootstrap.sh`, get a fully configured system.
Every decision is minimal, idempotent, declarative, and auditable.

Full architecture and decision records live in `docs/`.

---

## Repository Structure

```
/opt/arche/                   # canonical location, ~/arche symlinks here per user
├── bootstrap.sh              # orchestrator — runs all scripts in order
├── Justfile                  # day-to-day interface: just <target>
├── CLAUDE.md                 # this file
│
├── docs/                     # architecture, decisions, component status
│   ├── architecture.md
│   ├── decisions.md
│   └── status.md
│
├── tests/                    # validation scripts
│   └── run.sh                # test runner: just test
│
├── themes/                   # source of truth for all visual values
│   ├── schema.sh             # variable registry — names, types, defaults
│   ├── ember.sh              # active theme (warm amber on deep charcoal)
│   └── active -> ember.sh    # symlink to current theme
│
├── templates/                # .tmpl files rendered by theme engine (envsubst)
│
├── packages/                 # package registry — data only, no logic
│   └── *.sh                  # each file: PACMAN_PKGS=() and AUR_PKGS=()
│
├── scripts/
│   ├── lib.sh                # shared primitives — all scripts source this
│   ├── theme.sh              # theme engine: apply / switch / list
│   └── 00-preflight.sh ... 12-boot.sh
│
├── system/                   # system configs (/etc/) — symlinked by scripts, not stow
│   ├── etc/
│   │   ├── pacman.conf       # pacman config (parallel downloads, repos)
│   │   └── pacman.d/hooks/   # pacman hooks (snapper snapshots, boot cleanup)
│   └── usr/local/bin/
│       ├── boot-cleanup      # remove old UKI/kernels from /boot after upgrade
│       └── snapper-pacman    # create pre/post btrfs snapshot pairs
│
├── tools/                    # custom binaries
│   └── bin/                  # pre-built binaries from external repos (symlinked to system)
│       ├── arche-legion      # Lenovo Vantage replacement (built externally)
│       ├── arche-denoise     # Rust CLI — file/pipe GPU noise suppression
│       ├── arche-denoise-mic # C daemon — PipeWire virtual mic (Maxine)
│       └── arche-share-picker # GTK4 screen-share source picker (xdph custom_picker_binary)
│
└── stow/                     # behavior configs — symlinked via GNU Stow to $HOME
    ├── fish/                 # shell config (D018 — restored from D003)
    ├── kitty/                # terminal config
    ├── starship/             # prompt config
    ├── mpv/                  # media player
    ├── hypr/                 # Hyprland compositor config (D023 — restored from D021)
    ├── rofi/                 # Spotlight-style app launcher
    ├── cliphist/             # clipboard history
    ├── arche-scripts/        # user scripts (wallpaper, popup, powermenu, etc.)
    ├── nvim/                 # LazyVim + catppuccin
    ├── btop/                 # system monitor
    ├── tmux/                 # terminal multiplexer
    ├── kvantum/              # Qt style engine
    ├── qt6ct/                # Qt6 config
    ├── pipewire/             # audio daemon
    ├── wireplumber/          # audio session manager
    └── vivaldi/              # browser config
```

---

## The Three-Layer Config Split

Every config file belongs to exactly one layer. Never mix them.

**TEMPLATES** — configs that contain colors, fonts, sizes, cursors, icons, or spacing.
Rendered by theme.sh using envsubst. Output is gitignored.

**STOW PACKAGES** — configs that contain behavior: keybinds, module lists, rules, logic.
Symlinked directly via GNU Stow from `stow/`. Committed as-is.

**GENERATED OUTPUT** — files produced by rendering templates.
Live in ~/.config/. Never committed.

Decision rule: does this config contain colors/fonts/sizes?
- No → stow only. Yes → behavior in stow, visual in templates. All visual → template only.

See `docs/decisions.md` D005 for the per-component mapping.

---

## Theme System

`themes/schema.sh` is the single source of truth for all variable names, types, and defaults.
Theme files (e.g. `themes/ember.sh`) assign values. `lib.sh` reads the schema to validate,
export, and derive `_NOHASH` variants automatically. See `docs/theme-standard.md` for full spec.

Active theme: `themes/ember.sh` (warm amber on deep charcoal).

Variable groups defined in schema.sh:
- `SCHEMA_COLORS_REQUIRED` — core palette (11 vars, must be #hex6)
- `SCHEMA_COLORS_OPTIONAL` — extended palette (12 vars, defaults from required)
- `SCHEMA_FONTS_REQUIRED` — font families (2 vars)
- `SCHEMA_INTEGERS_REQUIRED` — layout values (7 vars, must be numeric)
- `SCHEMA_INTEGERS_OPTIONAL` — notification/component sizes (11 vars, defaults from required)
- `SCHEMA_ALPHA_OPTIONAL` — alpha hex suffix (1 var)
- `SCHEMA_APPEARANCE_REQUIRED` — cursor/icon/GTK theme names (3 vars)
- `SCHEMA_APPEARANCE_INTEGERS` — cursor size (1 var)

scripts/theme.sh renders templates via envsubst and reloads affected services.
nvim handles its own theming via catppuccin/nvim plugin — excluded from templates.

---

## Package Registry

Each file in packages/ declares two arrays only — no logic:
```bash
PACMAN_PKGS=()
AUR_PKGS=()
```

lib.sh provides `install_group <file>` which iterates both arrays idempotently.
Scripts call install_group, never call pacman/paru directly.
Removal is always manual (`paru -Rns`).

---

## lib.sh Primitives

All scripts source lib.sh and use only these functions:

```
log_info <msg>          — [INFO] message
log_ok <msg>            — [✓] message
log_warn <msg>          — [~] message (skipped / already done)
log_err <msg>           — [✗] message

pkg_install <pkg...>    — pacman -S --needed, skip if installed
aur_install <pkg...>    — paru -S --needed, print PKGBUILD URL first
stow_pkg <name>         — stow -d stow/ -t $HOME, dry-run conflict check first
svc_enable [--user] <name>  — systemctl enable + start, skip if active
theme_render <component...> — render templates, reload services
install_group <file>    — source packages file, run pkg_install + aur_install
```

---

## scripts/ Conventions

- Every script starts with: `source "$(dirname "$0")/lib.sh"`
- Every script is independently runnable: `bash scripts/05-hyprland.sh`
- bootstrap.sh runs them in numeric order, captures exit codes, prints summary
- Scripts do exactly four things: install packages, stow config, enable services, verify
- Bash only. No Python in scripts.
- No --noconfirm anywhere.
- Use $HOME not hardcoded paths.
- Guards before every action — check before act, never assume.

---

## Testing

Tests live in `tests/` and run via `just test`. Three levels:

**Lint** — static analysis, runs everywhere (CI-safe, no root needed):
- `bash -n` on all scripts and package files
- `fish --no-execute` on all stow/fish/ configs
- `shellcheck` on all bash scripts
- Package files declare only arrays (no side effects)
- Theme files export all required variables
- Templates reference only defined theme variables

**Stow** — verify symlink integrity (no root needed):
- `stow -d stow -t $HOME -n <pkg>` dry-run passes for all packages
- No stow conflicts between packages
- Stow targets match expected paths

**Integration** — verify installed state (needs live system):
- Commands from packages/ are available in PATH
- Services from scripts are active
- Rendered templates match expected output
- Bash config loads without errors: `bash -lc 'echo ok'`

Run: `just test` (lint only), `just test-stow`, `just test-all` (includes integration).

Every new script or config must have at least lint coverage. Add a test when adding a component.

---

## Popup Convention (Floating TUI Windows)

Any TUI app that should open as a centered floating window uses kitty's `--class popup`.
A Hyprland window rule in `stow/hypr/.config/hypr/windows.conf` matches `popup` on window
class and applies: float, center, fixed size.

**To launch a popup TUI from a keybinding:**
```
kitty --class popup -e bluetui
```

**To add a new popup:** use `--class popup` in the keybinding. The hypr rule handles the rest.

The `arche-popup` helper in `stow/arche-scripts/.local/bin/arche/` wraps this pattern —
prefer `arche-popup <cmd>` in keybindings over raw `kitty --class popup -e <cmd>`.

---

## Tools

Pre-built binaries live in `tools/bin/`. Source code stays in external repos under `~/projects/system/`.

- `arche-legion` — Lenovo Vantage replacement (battery, fan, profile, camera, USB, Fn lock)
- `arche-denoise` — Rust CLI: file/pipe GPU noise suppression (`clean`, `setup`, `status`)
- `arche-denoise-mic` — C daemon: PipeWire virtual mic with Maxine GPU denoising
- `arche-share-picker` — GTK4 screen-share source picker; xdph's `custom_picker_binary` (D027)

**Deploy:** symlinks at `system/usr/local/bin/arche/*` point into `tools/bin/`, auto-linked
to `/usr/local/bin/arche/` by `link_system_all` in `00-preflight.sh`. `/etc/profile.d/arche.sh`
and `/etc/fish/conf.d/arche.fish` (also in `system/`) prepend that directory to PATH for
every user and every shell.

**arche-denoise SDK:** installed system-wide at `/usr/local/share/arche/denoise/` via
`sudo arche-denoise setup --system` (run by `09-apps.sh`). One SDK install, all users.

**Update workflow:** build in the external repo, copy the new binary into `tools/bin/` — the
symlink chain (`/usr/local/bin/arche/X → system/usr/local/bin/arche/X → tools/bin/X`) picks
it up immediately.

---

## External Shell (arche-shell / Quickshell)

The Quickshell panel source (bar + control-center + notifications) is NOT vendored —
it lives in its own repo at <https://github.com/Dhruvpatel-10/quickshell> and is
cloned to `~/projects/system/arche-shell/` by `scripts/07-panel.sh`. That script
symlinks `~/.config/quickshell/` → the clone, so hot-reload on file save just works
when iterating. See D023.

---

## Stow Convention

All stow packages live under `stow/`. Each mirrors the home directory structure:
```
stow/fish/.config/fish/config.fish  →  ~/.config/fish/config.fish
```

The stow_pkg function: `stow -d "$ARCHE/stow" -t "$HOME" --no-folding "$pkg"`

---

## bootstrap.sh Behaviour

Assumes: repo is already cloned, user has sudo, running on Arch Linux.
`scripts/05-hyprland.sh` installs Hyprland itself, SDDM, and the Wayland
utility stack — no prior desktop install required.
Does not: clone the repo, configure SSH keys, set up secrets.
Runs: 00-preflight through 12-boot in order. Each section prompts y/N/a(ll).
Each script is independently idempotent.
Ends with: `theme apply`, then a summary table.

**Boot chain (D024).** `12-boot.sh` is the last script because it rewrites the
boot chain: switches mkinitcpio to `systemd` + `sd-encrypt` + `plymouth`, writes
a UKI preset, installs the `arche` Plymouth theme (subtle lavender + ARCHE
wordmark), rewrites `/etc/crypttab.initramfs` with the real LUKS UUID, and
rebuilds UKIs. After it runs, the LUKS passphrase still works (rendered by
Plymouth). To activate TPM2+PIN unlock, the user runs `just tpm-enroll`
separately — we never touch keyslots from bootstrap.

**Reboot gate.** `00-preflight.sh` runs `pacman -Syu`. If the upgrade replaces the
running kernel (`/usr/lib/modules/$(uname -r)` no longer exists), preflight exits
with code 2 and bootstrap pauses, prompting the user to reboot. After reboot,
re-run `bash bootstrap.sh` — every step is idempotent, so preflight becomes a
fast no-op and bootstrap continues with `01-base` onward on the new kernel.
Pattern: run once → reboot if prompted → run again to finish.

---

## Justfile Targets (minimum required)

```
install          → bash bootstrap.sh
theme target     → bash scripts/theme.sh {{target}}
switch theme     → bash scripts/theme.sh switch {{theme}}
themes           → bash scripts/theme.sh list
test             → bash tests/run.sh lint
test-stow        → bash tests/run.sh stow
test-all         → bash tests/run.sh all
```

One target per component matching its script:
preflight, base, security, gpu, audio, hyprland, shell, panel, runtimes, apps, stow, appearance, boot

---

## System State — Ground Truth

### Package Management
- pacman + paru (AUR helper)
- Always use --needed flag for idempotency
- Remove with -Rns never bare -R

### Active Runtimes
- Node.js v24.13.0 via fnm (NOT nvm)
- Python 3.14.3 system
- Go 1.26.0 local ~/go/bin
- Rust 1.94.0 via rustup
- Bun 1.3.5 via ~/.bun
- Docker 29.3.0 system

### Key CLI Tools
fzf, eza, bat, ripgrep, fd, zoxide, lazygit, lazydocker,
glow, dust, btop, nvtop, jq, yq, gum, just, aria2, gh, stow

### Desktop Stack
- Hyprland (Wayland compositor), uwsm session wrapper, SDDM (Breeze theme)
- Quickshell panel (bar + control-center + notifications + toasts) — external
  `arche-shell` repo cloned by `07-panel.sh`. See D023.
- rofi-wayland (app launcher), grim + slurp + satty (screenshots)
- hyprlock (lock screen), hypridle (idle management), hyprsunset (night light)
- awww (wallpaper — successor to swww), cliphist (clipboard history), hyprpolkitagent (auth)
- xdg-desktop-portal-hyprland

### Lenovo Legion Pro 5 (16ARX8)
- ideapad_laptop + lenovo_wmi_gamezone kernel modules (loaded)
- Battery conservation mode via sysfs (cap ~80%)
- Platform profiles: low-power, balanced, performance, max-power
- Fan mode control (auto / full speed)
- Camera kill switch, USB charging toggle, Fn lock
- arche-legion TUI manages all of the above (Super+Ctrl+G)

### NVIDIA
- nvidia-open-dkms 590.48.01 (open kernel module)
- CUDA 13.1 at /opt/cuda
- Modules in initramfs: nvidia nvidia_modeset nvidia_uvm nvidia_drm btrfs
- Bootloader: systemd-boot (NOT GRUB, NOT Limine) — boots UKIs from `/boot/EFI/Linux/`
- Pre-boot UI: Plymouth + `arche` theme (subtle purple with ARCHE wordmark) — D024
- Disk unlock: LUKS2 with TPM2 + PIN via `sd-encrypt` + `systemd-cryptenroll`, PCRs 0+7
- Filesystem: btrfs with snapper snapshots

### Audio
- Full pipewire stack: pipewire + alsa + jack + pulse + wireplumber

### Theming
- Ember theme (#13151c base, #cdc8bc text, #c9943e amber)
- Primary mono font: MesloLGS Nerd Font Mono (Menlo lineage)
- UI sans font: IBM Plex Sans

### Security
- Firewall: ufw active, nftables disabled (UFW sole manager)
- SSH: key-only auth (ed25519), no password auth, no root login
- DNS: NextDNS (DoT) primary, Cloudflare (DoT) fallback, DNSSEC allow-downgrade
- Tailscale: active — Syncthing/KDE Connect routed through tailscale0 (kdeconnect works on Hyprland too)
- Kernel: sysctl hardening (SYN cookies, rp_filter, ptrace, BPF, kptr_restrict)
- Lid close: explicit logind suspend (battery + AC), ignore docked
- WiFi: MAC address randomization (NetworkManager or iwd)
- CPU: amd-ucode for microcode vulnerability patches
- USB: USBGuard blocks unknown devices; usb-inspect for sandboxed inspection
- Sandboxing: firejail for untrusted apps and AppImages
- Secrets: API keys in ~/.config/fish/local.fish (not tracked in git)

---

## Current State — All Components Built

Infrastructure: bootstrap.sh, Justfile, lib.sh, theme.sh, tests/run.sh, docs/
Scripts: 13 numbered scripts (00-preflight through 12-boot)
Packages: 11 registry files (base, security, gpu-nvidia, audio, hyprland, shell, panel, runtimes, apps, appearance, boot)
Themes: ember.sh (active), schema.sh (variable registry)
Templates: btop, fish, glow, gtk-3.0, gtk-4.0, hypr, arche-share-picker, kitty, legion, mpv, qt6ct, rofi, starship, tmux
Stow: see Repository Structure above
System: pacman.conf, 3 pacman hooks, 3 system binaries, sddm.conf.d/10-arche.conf

See `docs/status.md` for full tracking.

---

## Active Known Issues

See `docs/status.md` for the full table.

---

## Rules Claude Code Must Follow

1. Never write colors, fonts, or sizes into stow package configs — use templates or themes/.
2. Never add package installs inside scripts directly — use install_group and packages/.
3. Never use --noconfirm.
4. Never hardcode /home/stark — always $HOME.
5. Never commit generated files (style.css, colors.conf, rendered configs).
6. Every new script must be independently runnable.
7. Conventional commits: feat/fix/chore/docs/refactor. Scope = component name.
8. If a config file's layer is ambiguous, ask before creating it.
9. Before installing any AUR package, flag it and show the PKGBUILD source URL.
10. When adding a new component, touch all required places: packages/, templates/ (if visual), stow/, scripts/.
11. Every new script or config must have at least lint-level test coverage.
12. Keep docs/ updated when making structural changes or decisions.
13. When adding a new floating TUI popup, use `kitty --class popup -e <cmd>` (or `arche-popup <cmd>`) — the hypr window rule handles float/center/size.
14. Hyprland window rules live in `stow/hypr/.config/hypr/windows.conf`. Do not hardcode rules in scripts.

---

## What NOT to Do
- Do not suggest Oh My Zsh, zinit, bash-it, oh-my-bash, ble.sh, bash-preexec, or carapace — fish + fisher + atuin is the stack (D018 reverses D016, restores D003)
- Do not install fisher from AUR — install it from upstream curl into `~/.config/fish/functions/fisher.fish`. See `06-shell.sh`.
- Do not use GRUB or Limine syntax — bootloader is systemd-boot (D024)
- Do not reference the old `encrypt` hook or `cryptdevice=` cmdline — we use `sd-encrypt` + `/etc/crypttab.initramfs` for TPM2 unlock (D024)
- Do not reference nvm — fnm is the active Node manager
- Do not reference pyenv — not installed
- Do not reference bash, zsh, ble.sh, bash-preexec, or carapace as the active shell — fish is the shell (D018)
- Do not hardcode /home/stark — use `$HOME` or `~`
- Do not suggest storing secrets in dotfiles — `~/.config/fish/local.fish` is the pattern (gitignored)
- Do not reference KDE Plasma, KWin, KRunner, Plasma Login Manager, Spectacle, kscreenlocker, Powerdevil, Klipper, kde-gtk-config — removed in D023, Hyprland is the desktop
- Do not reference Waybar, Mako, SwayOSD, syshud — Quickshell (arche-shell) replaces bar/notifications/OSD in one layer (D023)
- Do not reference plasma-login-manager — SDDM is the greeter (D023 reverts D022)
- Do not vendor SilentSDDM or any SDDM theme — default Breeze ships with sddm and is what we use (D023)
