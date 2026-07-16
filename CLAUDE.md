# Claude Code — Global Standing Instructions

## Who I Am
- User: stark
- Host: Arch Linux 6.x | Lenovo Legion Pro 5 16ARX8 | RTX 4060 Laptop | AMD Ryzen | Hyprland (Wayland) + DankMaterialShell (dms)
- Primary interface: Claude Code (terminal, TUI-first)
- Shell: Fish + Atuin (Ctrl-R) + Fisher (plugins) | Prompt: Starship | Terminal: Kitty
- Dotfiles: `/opt/arche` (shared across users), per-user `~/arche` → `/opt/arche` symlink. Managed with GNU Stow 2.4.1. See D014.

## Goal
Clone repo on fresh Arch install, run `bootstrap.sh`, get fully configured system.
All decisions: minimal, idempotent, declarative, auditable.

Full architecture and decision records in `docs/`.

---

## Repository Structure

```
/opt/arche/                   # canonical location, ~/arche symlinks here per user
├── install.sh                # OS-detecting curl installer — clone + exec bootstrap
├── bootstrap.sh              # single entrypoint: subcommands install/doctor/clean
├── Justfile                  # day-to-day interface entry — imports just/*.just
├── just/                     # modular Just targets (user, scripts, theme, test, util)
├── CLAUDE.md                 # this file
│
├── docs/                     # architecture, decisions, component status
│   ├── architecture.md
│   ├── decisions.md
│   ├── redesign.md           # design doc for the core+profiles+DSL layout (D033)
│   └── status.md
│
├── tests/                    # validation scripts
│   └── run.sh                # test runner: just test
│
├── core/                     # platform-agnostic engine (bash 3.2 safe)
│   ├── lib.sh                # portable primitives — every step sources this
│   ├── registry.sh           # package DSL parser + resolver (registry_install …)
│   ├── runner.sh             # step-manifest executor (prompt / --yes / reboot gate)
│   ├── doctor.sh             # `bootstrap.sh doctor [--repair]` health checks
│   ├── clean.sh              # `bootstrap.sh clean [--system|--packages]`
│   └── adapters/             # per-OS seam (pkg_backend, svc_enable, link_system_*, …)
│       ├── arch.sh           # pacman / paru, systemd, /etc linking
│       └── macos.sh          # Homebrew formula / cask, dscl, no-op services
│
├── theming/                  # entire theme system bundled here (UNCHANGED engine)
│   ├── engine.sh             # apply / switch / list / validate
│   ├── theme-lib.sh          # portable theme fns (theme_validate/theme_render) —
│   │                         #   sourced by both engine.sh and core/lib.sh
│   ├── themes/               # value sets
│   │   ├── schema.sh         # variable registry — names, types, defaults
│   │   ├── ember.sh          # default theme (warm amber on deep charcoal)
│   │   ├── frost.sh          # alt theme (muted teal glassmorphism)
│   │   └── active -> X.sh    # symlink to current theme
│   └── templates/            # per-app output specs (convention-over-config)
│       ├── <app>/*.tmpl      # envsubst input → ~/.config/<app>/<file>
│       ├── <app>/_emit.sh    # custom emitter (e.g. arche/ writes theme.json)
│       └── <app>/_reload.sh  # live-reload hook (run after render)
│
├── packages/                 # package registry — data only, no logic
│   └── *.reg                 # tool DSL: `tool <name> arch=kind:pkg macos=kind:pkg`
│
├── profiles/                 # ordered steps + stow/theme manifests, per platform
│   ├── linux-hyprland/       # full Arch + Hyprland desktop (default on Arch)
│   │   ├── profile.sh        # PROFILE_STOW/PROFILE_THEME + profile_steps()
│   │   └── steps/            # 00-preflight … 13-dms (moved from old scripts/)
│   ├── macos/                # macOS (Apple Silicon) CLI + terminal + theme
│   │   └── profile.sh
│   └── server/               # headless Arch CLI skeleton
│       └── profile.sh
│
├── system/                   # system configs (/etc/) — symlinked by adapter, not stow
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
│       └── arche-denoise-mic # C daemon — PipeWire virtual mic (Maxine)
│
│   # NOTE: desktop shell is dms (DankMaterialShell), package-managed at
│   # /usr/share/quickshell/dms/, set up by profiles/linux-hyprland/steps/13-dms.sh —
│   # see D032. The old hand-rolled shell/ panel was removed.
│
└── stow/                     # behavior configs — symlinked via GNU Stow to $HOME
    ├── fish/                 # shell config (D018 — restored from D003)
    ├── kitty/                # terminal config
    ├── starship/             # prompt config
    ├── mpv/                  # media player
    ├── hypr/                 # Hyprland compositor config (D023 — restored from D021)
    ├── cliphist/             # clipboard history
    ├── arche-scripts/        # user scripts (wallpaper, popup, powermenu, etc.)
    ├── nvim/                 # LazyVim + catppuccin
    ├── btop/                 # system monitor
    ├── tmux/                 # terminal multiplexer
    ├── pipewire/             # audio daemon
    ├── wireplumber/          # audio session manager
    └── vivaldi/              # browser config
```

---

## Platforms & Profiles

The repo is a **shared core + platform adapters + profiles** design (see
`docs/redesign.md`, D033). One `core/` engine runs anywhere bash + stow exist;
platform specifics live in `core/adapters/<platform>.sh`; concrete package/step
choices are data under `profiles/<name>/`.

| Profile | Platform | What it sets up |
|---|---|---|
| `linux-hyprland` | Arch Linux (default) | Full desktop: NVIDIA, Hyprland, dms, encrypted boot, audio, apps |
| `macos` | macOS Apple Silicon | Shared CLI tools, Ghostty terminal, editor, shell, theme (Homebrew) |
| `server` | headless Arch | CLI tools + shell + prompt only; no desktop, GPU, or audio |

One linear install for every platform: `bash bootstrap.sh`. It auto-selects the
profile by `uname` (override with `--profile NAME`), then hands the profile's
ordered step list to `core/runner.sh`. The `install.sh` curl one-liner clones
the repo to the right root and execs `bootstrap.sh` for you.

---

## The Three-Layer Config Split

Every config belongs to exactly one layer. Never mix.

**TEMPLATES** — configs with colors, fonts, sizes, cursors, icons, or spacing.
Rendered by `theming/engine.sh` via envsubst. Output gitignored.

**STOW PACKAGES** — configs with behavior: keybinds, module lists, rules, logic.
Symlinked via GNU Stow from `stow/`. Committed as-is.

**GENERATED OUTPUT** — files produced by rendering templates.
Live in ~/.config/. Never committed.

Decision rule: does config contain colors/fonts/sizes?
- No → stow only. Yes → behavior in stow, visual in templates. All visual → template only.

See `docs/decisions.md` D005 for per-component mapping.

---

## Theme System

Everything theme-related lives under `theming/`:

- `theming/themes/schema.sh` — single source of truth for variable names + types
- `theming/themes/<name>.sh` — value sets (Ember, Frost, …)
- `theming/themes/active` — symlink to active theme
- `theming/templates/<app>/` — per-app output specs
- `theming/engine.sh` — apply / switch / list / validate

Active theme: `theming/themes/ember.sh` (warm amber on deep charcoal).

**Two consumption tiers, both fed from same exported vars per apply:**

| Tier | Mechanism | Path |
|---|---|---|
| Foreign apps (kitty, hypr, gtk, mpv, …) | envsubst `*.tmpl` → app's required format | `~/.config/<app>/` |
| Arche-owned (dms shell, future tools) | `_emit.sh` writes canonical JSON | `/opt/arche/run/{theme.json, dms-theme.json}` (system-shared) |

**Per-component sidecar convention:**

```
theming/templates/<component>/
├── *.tmpl       — envsubst input (foreign-app tier; output strips .tmpl)
├── _emit.sh     — custom emitter; replaces .tmpl rendering when present
└── _reload.sh   — live-reload hook; sourced after render. Absent = silent.
```

Engine logic: walk dirs → if `_emit.sh` exists run it, else envsubst all `*.tmpl` →
if `_reload.sh` exists run it. No central case statement. Add a new component =
add a dir + files. Remove = delete the dir.

Variable groups in `theming/themes/schema.sh`:
- `SCHEMA_COLORS_REQUIRED` — core palette (11 vars, must be #hex6)
- `SCHEMA_COLORS_OPTIONAL` — extended palette (12 vars, defaults from required)
- `SCHEMA_FONTS_REQUIRED` — font families (2 vars)
- `SCHEMA_INTEGERS_REQUIRED` — layout values (7 vars, must be numeric)
- `SCHEMA_INTEGERS_OPTIONAL` — notification/component sizes (11 vars, defaults from required)
- `SCHEMA_ALPHA_OPTIONAL` — alpha hex suffix (1 var)
- `SCHEMA_APPEARANCE_REQUIRED` — cursor/icon/GTK theme names (3 vars)
- `SCHEMA_APPEARANCE_INTEGERS` — cursor size (1 var)

`theming/engine.sh` renders templates via envsubst, emits `theme.json` for
arche-owned consumers, and reloads affected services. nvim handles own theming
via catppuccin/nvim plugin — excluded from templates.

**Arche runtime dir:** `/opt/arche/run/` is the system-shared runtime
state directory for arche-owned consumers. `/opt/arche` is mode 2775 with
the `users` group, so any user on the host can read+write. Gitignored.
Currently holds `theme.json`. Future arche tools (TUI, daemons) that
need machine-wide state should emit / consume from here, not from a
per-user `~/.config/arche/`. Per-user state — config, history, secrets —
still lives under each user's `~/.config/` and `~/.local/state/`.

Why system-shared: the active theme symlink (`theming/themes/active`)
is already global, every Hyprland session on the host runs the same dms shell
(`/usr/share/quickshell/dms/`, D032), and `theming/templates/<app>/`
is the single source of truth for visuals — making the rendered JSON
per-user only created drift. One emit, one read, every shell re-paints.

---

## Package Registry

Each file in `packages/` is a `*.reg` file in the **tool DSL** — one tool per
line, mapping a logical name to a per-platform provider and install kind. This
is the single source of truth for every package across platforms, so a provider
can never drift silently again (this is what let the deprecated `cask mpv` slip
in against the `mpv` formula the config needs).

```
tool <name> <platform>=<kind>:<pkg> [<platform>=<kind>:<pkg> ...]

  platforms : arch, macos
  kinds     : arch  -> pacman | aur
              macos -> brew | cask

  tool mpv    arch=pacman:mpv         macos=brew:mpv       # never a cask
  tool gh     arch=pacman:github-cli  macos=brew:gh        # name differs per OS
  tool paru   arch=aur:paru
```

Omit a platform where the tool does not exist there. `#` starts a comment.
`core/registry.sh` parses these; steps call `registry_install <platform> <group>`
(where `<group>` is the `.reg` basename, e.g. `base`), never pacman/paru/brew
directly. Removal is always manual (`paru -Rns` on Arch). A `tests/` drift-guard
lint checks every line is well-formed, that no tool name is duplicated, that mpv
is never a cask, and that tealdeer/tldr never both appear.

---

## core/lib.sh Primitives

Every step sources `core/lib.sh` (kept bash 3.2 safe — macOS still ships 3.2).
It provides the portable primitives, then loads the right platform adapter
(`core/adapters/<platform>.sh`) and the package registry. Steps use only these:

```
# Portable (core/lib.sh)
log_info / log_ok / log_warn / log_err / log_step  — user-facing status lines
stow_pkg <name>              — symlink a stow package into $HOME (backs up conflicts)
unstow_pkg <name>            — remove a stow package's links (used by clean)
set_login_shell <path>       — make <path> the login shell (getent/dscl aware)
setup_fisher                 — install fisher from upstream + update fish plugins
curl_install_checked <url> <sha256|-> [interp]  — download + checksum + run installer
select_platform_variant <link> <linux> <macos>  — flip a per-OS config selector symlink
theme_render <component...>  — render templates, reload services (via theme-lib.sh)
registry_install <platform> <group...>  — install every tool for a platform from a .reg group

# Adapter interface (core/adapters/<platform>.sh)
pkg_backend <kind> <pkg...>  — install packages of a kind (pacman|aur or brew|cask)
svc_enable [--user] <name>   — systemctl enable + start (no-op on macOS)
link_system_file / link_system_all  — symlink system/ tree into /etc, /usr/local (Linux)
read_login_shell / arche_root / pkg_installed  — platform queries used by doctor
```

Steps never call pacman/paru/brew/systemctl directly — they go through
`registry_install`, `pkg_backend`, and `svc_enable`. (The Arch adapter still
defines the older `pkg_install`/`aur_install`/`install_group` helpers, but the
registry path is what steps use now.)

---

## Steps Convention

Steps are the numbered install scripts, now living under
`profiles/<profile>/steps/` (e.g. `profiles/linux-hyprland/steps/05-hyprland.sh`).
A profile's `profile.sh` lists them in order via `profile_steps()`; the runner
executes that list.

- Every step starts with: `source "$ARCHE/core/lib.sh"`
- Every step is independently runnable: `bash profiles/linux-hyprland/steps/05-hyprland.sh`
- Steps install packages with `registry_install <platform> <group>`, link config
  with `stow_pkg`, enable services with `svc_enable`, and verify — nothing else.
- `run_profile` (core/runner.sh) walks the step list, prompts y/N/a, captures
  exit codes, honors `--only <id>` / `--yes`, and prints a summary.
- Bash only. No Python in steps.
- No --noconfirm anywhere.
- Use $HOME not hardcoded paths.
- Guards before every action — check before act, never assume.

---

## Testing

Tests in `tests/`, run via `just test`. Three levels:

**Lint** — static analysis, runs everywhere (CI-safe, no root needed):
- `bash -n` on all core/, profile, and step scripts
- `fish --no-execute` on all stow/fish/ configs
- `shellcheck` on all bash scripts
- Package registry drift-guard: every `.reg` line well-formed, no duplicate tool
  names, mpv never a cask, no tealdeer/tldr conflict
- Theme files export all required variables
- Templates reference only defined theme variables

**Stow** — verify symlink integrity (no root needed):
- `stow -d stow -t $HOME -n <pkg>` dry-run passes for all packages
- No stow conflicts between packages
- Stow targets match expected paths

**Integration** — verify installed state (needs live system):
- Commands from packages/ available in PATH
- Services from scripts active
- Rendered templates match expected output
- Bash config loads without errors: `bash -lc 'echo ok'`

Run: `just test` (lint only), `just test-stow`, `just test-all` (includes integration).

Every new script or config needs at least lint coverage. Add test when adding component.

---

## Popup Convention (Floating TUI Windows)

TUI apps that open as centered floating window use kitty's `--class popup`.
Hyprland window rule in `stow/hypr/.config/hypr/windows.conf` matches `popup` on window
class and applies: float, center, fixed size.

**To launch popup TUI from keybinding:**
```
kitty --class popup -e bluetui
```

**To add new popup:** use `--class popup` in keybinding. Hypr rule handles the rest.

`arche-popup` helper in `stow/arche-scripts/.local/bin/arche/` wraps this pattern —
prefer `arche-popup <cmd>` in keybindings over raw `kitty --class popup -e <cmd>`.

---

## Tools

Pre-built binaries in `tools/bin/`. Source code in external repos under `~/projects/system/`.

- `arche-legion` — Lenovo Vantage replacement (battery, fan, profile, camera, USB, Fn lock)
- `arche-denoise` — Rust CLI: file/pipe GPU noise suppression (`clean`, `setup`, `status`)
- `arche-denoise-mic` — C daemon: PipeWire virtual mic with Maxine GPU denoising

Note: screen-share picker is now `hyprland-preview-share-picker` (AUR), not tools/ binary — see D028.

**Deploy:** symlinks at `system/usr/local/bin/arche/*` point into `tools/bin/`, auto-linked
to `/usr/local/bin/arche/` by `link_system_all` in `00-preflight.sh`. `/etc/profile.d/arche.sh`
and `/etc/fish/conf.d/arche.fish` (also in `system/`) prepend that directory to PATH for
every user and shell.

**arche-denoise SDK:** installed system-wide at `/usr/local/share/arche/denoise/` via
`sudo arche-denoise setup --system` (run by `09-apps.sh`). One SDK install, all users.

**Update workflow:** build in external repo, copy new binary into `tools/bin/` — symlink
chain (`/usr/local/bin/arche/X → system/usr/local/bin/arche/X → tools/bin/X`) picks up immediately.

---

## Desktop Shell — DankMaterialShell (dms)

The bar + control-center + notifications + OSD + launcher + clipboard + power
menu are all provided by **DankMaterialShell (dms)** — a maintained
Quickshell-based shell from the official Arch `extra` repo (`dms-shell`,
`dms-shell-hyprland`). It replaced the hand-rolled `/opt/arche/shell/` panel
(deleted). See D032.

- Shell source: `/usr/share/quickshell/dms/` (package-managed, not in repo).
- Started via its systemd **user service** `dms.service` (Type=dbus, owns
  `org.freedesktop.Notifications`, `Restart=on-failure`). autostart.conf does
  `systemctl --user start dms.service`.
- Setup: `profiles/linux-hyprland/steps/13-dms.sh` (`just dms`) — install, link service drop-in +
  resume hook, emit theme, seed per-user `settings.json`, enable service.
- Theme: arche drives colors. `theming/templates/dms/_emit.sh` renders
  `/opt/arche/run/dms-theme.json` from the active theme; dms consumes it via
  `settings.json { currentThemeName: "custom", customThemeFile: … }`. Matugen
  disabled. Fonts seeded into per-user `settings.json`.
- Keybinds: Hyprland `bindings.conf` calls `dms ipc call <target> …`
  (spotlight, clipboard, powermenu, notifications, inhibit, bar).
- NVIDIA suspend freeze (#2250) worked around by
  `system/usr/lib/systemd/system-sleep/dms-restart`.
- Built-in polkit is OFF (`DMS_DISABLE_POLKIT=1`); hyprpolkitagent stays.

---

## Stow Convention

All stow packages under `stow/`. Each mirrors home directory structure:
```
stow/fish/.config/fish/config.fish  →  ~/.config/fish/config.fish
```

The stow_pkg function: `stow -d "$ARCHE/stow" -t "$HOME" --no-folding "$pkg"`

---

## bootstrap.sh Behaviour

`bootstrap.sh` is the single entrypoint with subcommands:

```
bash bootstrap.sh                  # install (default) — asks before each step
bash bootstrap.sh --yes            # install without asking
bash bootstrap.sh --profile NAME   # force a profile (linux-hyprland | macos | server)
bash bootstrap.sh --only ID        # run just one step
bash bootstrap.sh doctor [--repair]  # health-check the setup; repair fixes safe things
bash bootstrap.sh clean [--system|--packages]  # unlink configs (and optionally more)
```

It picks the profile by platform (`arch` → linux-hyprland, `macos` → macos),
re-execs under a modern bash if one is installed (macOS ships 3.2), sources the
core, loads the profile, and runs its ordered steps through `core/runner.sh`.

Assumes: repo cloned, user has sudo (Linux). On the linux-hyprland profile,
`steps/05-hyprland.sh` installs Hyprland, SDDM, and the Wayland utility stack —
no prior desktop required. Does not: clone repo, configure SSH keys, set up
secrets. Steps run in order, each section prompts y/N/a(ll) (unless `--yes`),
each step is independently idempotent. The linux-hyprland profile ends with a
`theming/engine.sh apply` pass, then a summary table.

**Boot chain (D024).** `steps/12-boot.sh` runs late because it rewrites the boot chain:
switches mkinitcpio to `systemd` + `sd-encrypt` + `plymouth`, writes UKI preset,
installs `arche` Plymouth theme (subtle lavender + ARCHE wordmark), rewrites
`/etc/crypttab.initramfs` with real LUKS UUID, rebuilds UKIs. After run, LUKS passphrase
still works (rendered by Plymouth). To activate TPM2+PIN unlock, user runs `just tpm-enroll`
separately — never touch keyslots from bootstrap.

**Reboot gate.** `steps/00-preflight.sh` runs `pacman -Syu`. If the upgrade replaces the
running kernel (`/usr/lib/modules/$(uname -r)` no longer exists), the step exits code 2;
because it is registered with the `reboot` flag, the runner pauses and prompts a reboot.
After reboot, re-run `bash bootstrap.sh` — every step idempotent, preflight becomes a fast
no-op, install continues with `01-base` onward on the new kernel.
Pattern: run once → reboot if prompted → run again to finish.

---

## Justfile Layout

Top-level `Justfile` sets `dotfiles := justfile_directory()`, imports modules under `just/`,
and defines the bootstrap targets. All other targets live in imported modules but remain
at top level in CLI (no namespace prefix). Run `just` or `just --list` for the grouped list.

| File              | Group        | Targets                                                                       |
|-------------------|--------------|-------------------------------------------------------------------------------|
| `Justfile`        | bootstrap    | `install`, `install-yes`, `doctor [repair=1]`, `clean`                        |
| `just/user.just`  | helpers      | `ssh-setup`, `multi-user-init`, `tpm-enroll`, `secondary-user`                |
| `just/scripts.just` | scripts    | `preflight`, `base`, `security`, `gpu`, `audio`, `hyprland`, `shell`, `runtimes`, `apps`, `stow`, `appearance`, `dms`, `dms-restart`, `boot` |
| `just/theme.just` | theme        | `theme-apply`, `theme-switch <name>`, `theme-list`                            |
| `just/test.just`  | test         | `test`, `test-stow`, `gate`, `test-all`                                       |
| `just/util.just`  | utilities    | `restow`, `relink`, `backup`, `sddm-preview`, `dns`, `sf-pro`                 |

Component targets in `just/scripts.just` map 1:1 to steps: `just <component>` runs the
matching `profiles/linux-hyprland/steps/NN-<component>.sh` (e.g. `just hyprland` →
`profiles/linux-hyprland/steps/05-hyprland.sh`).

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
- JDK 17 (jdk17-openjdk) — default Java; required by Android SDK build-tools and Gradle
- Android SDK at `/opt/android-sdk` (AUR `android-sdk` family) — `ANDROID_HOME` + PATH wired in `stow/fish/.config/fish/conf.d/android.fish`. Human users joined to `android-sdk` group by `08-runtimes.sh` for write access (sdkmanager). adb comes from `android-sdk-platform-tools` — never install `extra/android-tools` alongside, they collide on `/usr/bin/adb`.

### Key CLI Tools
fzf, eza, bat, ripgrep, fd, zoxide, lazygit, lazydocker,
glow, dust, btop, nvtop, jq, yq, gum, just, aria2, gh, stow

### Desktop Stack
- Hyprland (Wayland compositor), uwsm session wrapper, SDDM (Breeze theme)
- DankMaterialShell (dms) — bar + control-center + notifications + OSD +
  launcher + clipboard + power-menu in one Quickshell-based shell. Package-managed
  (`dms-shell`), runs as `dms.service` user unit, set up by `profiles/linux-hyprland/steps/13-dms.sh`. See D032.
- App launcher / clipboard / power-menu are dms's built-ins, bound via
  `dms ipc call …` in bindings.conf (D032). grim + slurp + satty (screenshots)
- hyprlock (lock screen), hypridle (idle management), hyprsunset (night light)
- awww (wallpaper — successor to swww), cliphist (clipboard history), hyprpolkitagent (auth)
- xdg-desktop-portal-hyprland + xdg-desktop-portal-gtk (Hyprland portal implements Screenshot/ScreenCast/GlobalShortcuts only — Settings/FileChooser/etc fall through to portal-gtk, which also bridges gsettings `color-scheme` → xdg `color-scheme` D-Bus property for Electron/Chromium/Vivaldi)

### Lenovo Legion Pro 5 (16ARX8)
- ideapad_laptop + lenovo_wmi_gamezone kernel modules (loaded)
- Battery conservation mode via sysfs (cap ~80%)
- Platform profiles: low-power, balanced, performance, max-power
- Fan mode control (auto / full speed)
- Camera kill switch, USB charging toggle, Fn lock
- arche-legion TUI manages all (Super+Ctrl+G)

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
- Sandboxing: firejail for untrusted apps and AppImages
- Secrets: API keys in ~/.config/fish/local.fish (not tracked in git)

---

## Current State — All Components Built

Infrastructure: install.sh, bootstrap.sh, Justfile, core/ (lib, registry, runner, doctor, clean, adapters/{arch,macos}), theming/engine.sh, tests/run.sh, docs/
Profiles: linux-hyprland (steps 00-preflight through 13-dms), macos, server
Packages: 12 `.reg` registry files (base, security, gpu-nvidia, audio, hyprland, shell, dms, runtimes, apps, appearance, boot, macos)
Themes: theming/themes/ember.sh (default), theming/themes/frost.sh, theming/themes/schema.sh
Templates: theming/templates/{arche, btop, dms, electron-flags, fish, fontconfig, ghostty, glow, gtk-3.0, gtk-4.0, hypr, hyprland-preview-share-picker, kitty, legion, mpv, starship, tmux}
Stow: see Repository Structure above
System: pacman.conf, 3 pacman hooks, 3 system binaries, sddm.conf.d/10-arche.conf

See `docs/status.md` for full tracking.

---

## Active Known Issues

See `docs/status.md` for full table.

---

## Rules Claude Code Must Follow

1. Never write colors, fonts, or sizes into stow package configs — use `theming/templates/` or `theming/themes/`.
2. Never add package installs inside steps directly — add a `tool` line to a `packages/*.reg` file and call `registry_install`.
3. Never use --noconfirm.
4. Never hardcode /home/stark — always $HOME.
5. Never commit generated files (style.css, colors.conf, rendered configs).
6. Every new script must be independently runnable.
7. Conventional commits: feat/fix/chore/docs/refactor. Scope = component name.
8. If config file layer ambiguous, ask before creating.
9. Before installing any AUR package, flag it and show PKGBUILD source URL.
10. When adding new component, touch all required places: packages/*.reg, theming/templates/ (if visual), stow/, and the relevant profile's steps/ + profile_steps().
11. Every new script or config needs at least lint-level test coverage.
12. Keep docs/ updated when making structural changes or decisions.
13. When adding new floating TUI popup, use `kitty --class popup -e <cmd>` (or `arche-popup <cmd>`) — hypr window rule handles float/center/size.
14. Hyprland window rules live in `stow/hypr/.config/hypr/windows.conf`. Do not hardcode rules in scripts.

---

## What NOT to Do
- Do not suggest Oh My Zsh, zinit, bash-it, oh-my-bash, ble.sh, bash-preexec, or carapace — fish + fisher + atuin is the stack (D018 reverses D016, restores D003)
- Do not install fisher from AUR — install from upstream curl into `~/.config/fish/functions/fisher.fish`. See `06-shell.sh`.
- Do not use GRUB or Limine syntax — bootloader is systemd-boot (D024)
- Do not reference old `encrypt` hook or `cryptdevice=` cmdline — use `sd-encrypt` + `/etc/crypttab.initramfs` for TPM2 unlock (D024)
- Do not reference nvm — fnm is active Node manager
- Do not reference pyenv — not installed
- Do not reference bash, zsh, ble.sh, bash-preexec, or carapace as active shell — fish is shell (D018)
- Do not hardcode /home/stark — use `$HOME` or `~`
- Do not suggest storing secrets in dotfiles — `~/.config/fish/local.fish` is pattern (gitignored)
- Do not reference KDE Plasma, KWin, KRunner, Plasma Login Manager, Spectacle, kscreenlocker, Powerdevil, Klipper, kde-gtk-config — removed in D023, Hyprland is desktop
- Do not reference Waybar, Mako, SwayOSD, syshud — dms (DankMaterialShell) provides bar/notifications/OSD in one layer (D032, supersedes D023)
- Do not install dunst, mako, or swaync — dms's `dms.service` is `Type=dbus` owning `org.freedesktop.Notifications`; any other notification daemon races it for the bus name on D-Bus auto-activation and hijacks toasts (D032, supersedes D023)
- Do not reference plasma-login-manager — SDDM is greeter (D023 reverts D022)
- Do not vendor SilentSDDM or any SDDM theme — default Breeze ships with sddm, that what we use (D023)