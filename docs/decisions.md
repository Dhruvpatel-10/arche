# Decision Log

Each entry records a significant choice, the reasoning, and any trade-offs.
Newest entries at the top.

---

## D016 — Bash replaces Fish, with vendored ble.sh + bash-preexec + carapace

**Date:** 2026-04-11
**Status:** Accepted
**Reverses:** D003 (Fish shell replaces Zsh)

Switching the interactive and login shell from Fish to GNU Bash, recovering
fish's autosuggestions, syntax highlighting, and abbreviations via a vendored
layer: `ble.sh` (readline replacement, pure bash), `bash-preexec`, and
`carapace-bin` (1000+ tool completions). Atuin from the `extra` repo provides
SQLite-backed fuzzy history in offline mode.

**Why:**
- Supply-chain minimalism — bypassing AUR PKGBUILDs for ble.sh, bash-preexec,
  and carapace. PKGBUILDs execute arbitrary build-time code; vendoring
  upstream pinned releases with auditable source removes that attack surface.
- Interactive shell == script shell: no more fish/bash context-switching
  when writing or pasting one-liners.
- ble.sh in 2026 is mature enough that the UX gap vs fish is ~5%. With
  `ble-sabbrev`, abbreviations expand inline and record expanded form in
  history — same muscle memory as fish `abbr`.

**Audit (2026-04-11, three parallel agents — all CLEAN):**
- **ble.sh** `b99cadb4` — single-maintainer (akinomyoga) with excellent commit
  hygiene; ~900 internal `eval`s all scoped to pre-parsed literals and state
  arrays; temp files under `umask 077` with TOCTOU guards; no runtime network;
  pinned CI; vendored as `make`-built output of the pinned commit.
- **bash-preexec** `a220343b` (23 commits ahead of 0.6.0 tag) — 2 `eval`s both
  parse bash's own `trap -p DEBUG` output; DEBUG trap recursion guarded;
  PROMPT_COMMAND preservation is array-aware and sanitized; no `/tmp`, no
  network. Post-tag commits are bash-5.3 + ble.sh compat fixes authored mostly
  by ble.sh's maintainer — directly de-risks the integration.
- **carapace-bin** `v1.6.4` (sha256 `885ee9f9...eff2` tarball / `b3e58ea3...`
  binary) — static Go (`CGO_ENABLED=0`), 46-line `go.sum`, zero runtime network,
  zero telemetry, safe argv-form `exec.Command`, writes confined to XDG dirs,
  no CVEs. Bus factor 1 (rsteube) is the only standing risk — mitigated by
  pinning the exact SHA.

**Layout:**
- `vendor/blesh/` — built output of `make` from pinned commit (4.6MB). Sourced
  directly via `/opt/arche/vendor/blesh/ble.sh` — no `/usr/share` install step.
- `vendor/bash-preexec/bash-preexec.sh` — 564-line pure bash. Same deal,
  sourced directly from `/opt/arche/vendor/bash-preexec/`.
- `tools/bin/carapace` — 65MB static binary, symlinked to
  `~/.local/bin/arche/carapace` by `06-shell.sh` (matches `arche-legion`
  pattern).
- `.source` file next to each vendored drop records upstream URL, pinned
  commit/tag, sha256 where applicable, audit date, and upgrade workflow.

**Load order (critical) in `stow/bash/.bashrc`:**
1. `bash-preexec.sh` (must precede atuin)
2. `ble.sh --attach=none` (defer heavy work)
3. `conf.d/[1-9]*.sh` — starship, zoxide, fnm, uv, ssh-agent, atuin, carapace
4. `functions/*.sh` — ported from fish
5. `aliases.sh` (contains `ble-sabbrev` calls, needs ble.sh sourced)
6. `~/.bash/local.bash` — gitignored secrets
7. `ble-attach` — MUST be last

**Abbreviations → `ble-sabbrev`:** all 21 fish abbreviations ported 1:1.
Space-triggered inline expansion, history records expanded form. Same UX.

**Aliases (5) and functions (22):** direct syntactic translation from
`stow/fish/` to `stow/bash/.bash/{aliases.sh,functions/*.sh}`.

**History caveat — read this:** `bash-preexec.sh:92-101`
(`__bp_adjust_histcontrol`) rewrites `HISTCONTROL=ignorespace` to `ignoredups`
and exports it. Leading-space commands (` export SECRET=...`) therefore become
visible to every `preexec_functions` hook (notably Atuin) and to bash history.
This is documented upstream but breaks the "space-prefix hides a command"
muscle memory. Put secrets in files (`~/.bash/local.bash`, gitignored), never
in command lines.

**Fish removed immediately (no rollback window held):**
- `stow/fish/` deleted from the repo.
- `templates/fish/` deleted (fish syntax-highlight colors no longer needed).
- `fish` dropped from `packages/shell.sh`.
- `scripts/06-shell.sh` no longer stows fish or touches `/etc/shells` for fish.
- Operator tasks on already-installed machines: `stow -D fish` to unlink the
  old symlinks, then `paru -Rns fish fisher` to remove the packages.

**Upgrade workflow for vendored tools:** documented inline in each
`.source` file. Always: clone → checkout new commit → re-run audit → build
(ble.sh only) → copy → update `.source`. Never call `ble-update`.

**Consequences:**
- `.claude/rules/secrets.md` covers `~/.bash/local.bash` only.
- `tests/run.sh` lint stage `bash -n`s the new `stow/bash/` tree and the
  vendored shell drops; the old `fish --no-execute` block is removed.
- Reverses D003. D003 stays in the log as historical record.

---

## D015 — hyprpaper replaces swww as wallpaper daemon

**Date:** 2026-04-11
**Status:** Accepted

Swapped `swww` for `hyprpaper` as the sole wallpaper daemon.

**Why:** hyprpaper is the official hyprwm tool and keeps the compositor stack
self-contained. swww's animated transitions were nice-to-have but not worth
the extra daemon.

**Why config-file interface, not hyprctl IPC:** hyprpaper 0.8 is a full
rewrite. The flat `preload =` / `wallpaper = ,path` syntax is gone — the
new format is a Hyprlang block:

```
splash = 0
ipc = 1

wallpaper {
    monitor =          # empty = wildcard / all monitors
    path = /abs/path/to/image.jpg
    fit_mode = cover
}
```

The IPC also changed: it's now a Hyprwire-protocol object model
(`hyprpaper_core_manager` → `get_wallpaper_object` → `path`/`fit_mode`/
`monitor_name`/`apply`), not the old `hyprctl hyprpaper preload/wallpaper`
subcommands. `hyprctl 0.54` doesn't speak this either, so any flat
preload/wallpaper hyprctl call returns `invalid hyprpaper request`.

Rather than chase versions or speak Hyprwire ourselves over the raw
socket, `arche-wallpaper` writes `~/.config/hypr/hyprpaper.conf` with the
new block syntax and restarts the daemon on every switch. Version-
agnostic, works today, costs ~200 ms per switch.

**Consequences:**
- `hyprpaper.conf` is script-owned (not stowed) — `arche-wallpaper` is the
  only writer, and autostart calls `arche-wallpaper random` on login instead
  of launching `hyprpaper` directly.
- Wallpapers live in-repo at `stow/hypr/.config/hypr/wallpapers/` so they
  ship with arche and stow symlinks them into `~/.config/hypr/wallpapers/`.
- New `toggle` subcommand and `SUPER SHIFT + P` bind cycle the sorted
  wallpaper list.
- No transitions, no wallpaper persistence across reboots.

---

## D014 — Repo lives at /opt/arche, shared between users

**Date:** 2026-04-11
**Status:** Accepted

Moved the canonical repo location from `$HOME/arche` to `/opt/arche`. Each
human user gets a per-user `~/arche` → `/opt/arche` symlink so anything
hardcoding the old path keeps working.

**Why:** This machine now has two human users (personal + work). Cloning
arche into each home directory is wasteful — the repo is the source of truth
for *system-wide* state (pacman packages, `/etc/` configs, the `system/` tree
that gets symlinked into root-owned paths). Two clones means two places to
keep in sync, two places to git pull, and two opportunities for the work
user's repo to drift from the personal user's. Worse, the personal user's
home is mode 700 (so the work user couldn't read the repo even if they
wanted to), and `/home/stark/arche/system/` is symlinked from `/etc/` —
which means root-owned paths point into a directory that one specific user
"owns". That's fragile.

**Why /opt:** /opt is the canonical FHS location for "add-on application
software packages" — exactly what arche is. /opt is mode 755 so every user
(and every system user, including `sddm`) can traverse it. Files inside
become group-readable + group-writable for the `users` group, with the
setgid bit on directories so files created by either user inherit
group=users. Both users get write access without any user owning the tree.

**Permissions model:**
- Owner: the primary user (the one who ran the migration / install.sh)
- Group: `users` (gid 100, the standard Arch shared group; both users
  must be members via `usermod -aG users <name>`)
- Files: 0664 (rw-rw-r--)
- Directories: 2775 (rwxrwsr-x with setgid bit, so new files inherit group)
- Executables (`*.sh`, `*.fish`, anything under `bin/` or `.local/bin/`): 0775

**Per-user state stays per-user:** stow targets `$HOME` for every package,
so each user gets their own `~/.config/*` symlinks pointing into the shared
`/opt/arche/stow/` tree. Per-user runtime managers (fnm, rustup, bun) install
under `$HOME` and are NOT shared — work and personal projects need different
toolchain versions, and sharing them invites version conflicts. Disk cost
of per-user runtimes is real (~2-5 GB per user) but it's the right cost.

**The compat symlink:** Anything that hardcodes `~/arche` or `$HOME/arche`
(yazi shortcut, `.claude/commands/*`, `.claude/skills/*`, etc.) keeps working
because each user's `~/arche` is a symlink to `/opt/arche`. This was a
deliberate choice to avoid touching dozens of files — the symlink is per-user
so paths remain user-agnostic without rewrites.

**Workflow:**
- **Fresh install:** `install.sh` clones to `/opt/arche` directly, sets perms,
  creates the symlink.
- **Existing install (migration):** `just multi-user-init` runs
  `helpers/migrate-to-opt.sh` which moves `$HOME/arche` → `/opt/arche`,
  sets perms, adds the current user to `users`, creates the compat symlink.
- **Adding a second user:** `sudo useradd -m -G wheel,users <name>`,
  then from that user's session: `cd /opt/arche && just secondary-user`.
  The `secondary-user` recipe runs only stow + the shell setup script —
  it skips the system-level scripts (00-05, 07-10, 12) because pacman packages
  and `/etc/` configs are already in place from the primary user's bootstrap.

**Things explicitly NOT changed:**
- `lib.sh::ARCHE` derivation — already correct, derives from script location
  so `/opt/arche/scripts/foo.sh` self-locates as `ARCHE=/opt/arche`. No code
  change needed.
- `Justfile::dotfiles` — uses `justfile_directory()`, also self-locating.
- `.claude/commands/*` and `.claude/skills/*` — keep `$HOME/arche` references
  because the per-user compat symlink resolves them correctly without
  baking the absolute path into Claude config.
- Per-user runtime managers — stay per-user. See "Per-user state" above.

**Files touched:**
- `helpers/migrate-to-opt.sh` — new, one-shot migration script
- `install.sh` — clones to `/opt/arche` instead of `$HOME/arche`, sets perms,
  creates symlink
- `Justfile` — adds `multi-user-init` and `secondary-user` recipes
- `stow/fish/.config/fish/conf.d/path.fish` — exports `ARCHE=/opt/arche`
- `README.md`, `CLAUDE.md`, `docs/architecture.md` — note the new convention

---

## D013 — SDDM + SilentSDDM replaces greetd + regreet + cage

**Date:** 2026-04-11
**Status:** Accepted — reverses D010

Replaced the greetd + greetd-regreet + cage login stack with SDDM running the
vendored `SilentSDDM` theme (modern glassmorphism, by uiriansan,
github.com/uiriansan/SilentSDDM).

**Why:** cage 0.2.1 has no way to pin the greeter to a specific output — its
only flags are `-m extend` (span all outputs) and `-m last` (last connected).
With a dual-monitor setup (laptop eDP-1 + external HDMI-A-1) the greeter
stretched across both screens and was unusable on the main display. The fix
options were (a) switch the kiosk compositor to sway, or (b) switch the whole
display manager to SDDM. SDDM won because it additionally gives a native
multi-user dropdown, session picker, and a GPL-licensed theme ecosystem —
features that were already wanted and would have required custom work on the
greetd path.

**Reversal of D010:** D010 removed SDDM specifically to avoid pulling in Qt
dependencies for a login screen. That calculus changed: Qt6 is already on the
system (hyprpolkitagent pulls qt6-base and qt6-declarative). Net new deps:
`sddm`, `qt6-5compat`, `qt6-svg`, `qt6-virtualkeyboard`, `qt6-multimedia-ffmpeg`
— all of which the SilentSDDM QML imports unconditionally even when those
features (virtual keyboard, animated video backgrounds) are unused. The
original objection no longer applies because those Qt6 deps are small relative
to what's already on disk.

**Theme choice — eucalyptus-drop → SilentSDDM:** the first attempt at this
migration vendored `sddm-eucalyptus-drop` (a Qt6 sugar-candy fork). It worked
but visually felt like a 2018-era Linux DE — the centered form on a static
background looked dated, and at 4K with HiDPI scaling the form rendered as a
narrow horizontal strip ("mobile UI" effect). Switched to SilentSDDM, which
ships modern glassmorphism, ~13 prebuilt color variants (catppuccin-mocha,
nord, everforest, default, etc.), animated background support, and a
proper avatar/dropdown system. eucalyptus-drop and its template were deleted
in the same commit — git history is the rollback path if SilentSDDM breaks.

**Theme vendoring:** SilentSDDM is a pure QML tree (~3.3 MB after pruning)
copied into `vendor/sddm-silent/`. Pruned from upstream:
- `backgrounds/*.mp4` — 16 MB of video wallpapers, not needed for static use
- `backgrounds/*.png` — accompanying poster frames for the videos
- `docs/` — preview screenshots, runtime irrelevant
- `flake.nix`, `default.nix`, `nix/` — NixOS module, not relevant on Arch
- `install.sh`, `test.sh`, `change_avatar.sh` — interactive setup scripts
Kept: `Main.qml`, `metadata.desktop`, `qmldir`, `LICENSE`, `README.md`,
`components/`, `configs/` (all 13 variants), `icons/`, `fonts/`, plus
3 still-image backgrounds. Upstream commit pinned in `.source`.

Copy (not symlink) because the `sddm` user runs with a clean PAM environment
and cannot traverse `/home/stark` (mode 700) to follow symlinks back into the
repo. The theme is installed by `05-hyprland.sh` via a `cp`-style mirror that
wipes the destination first to stay idempotent across upstream file removals.

**Theme config — not templated:** SilentSDDM does not use the standard SDDM
`theme.conf` — it has its own `configs/<variant>.conf` files in INI format,
and `metadata.desktop` selects the active variant via its `ConfigFile=` line.
The default config has 260+ keys spread across nested sections, and most of
the visual signature comes from per-variant background images, not color
values. Templating it from `themes/ember.sh` would be high-effort and
low-payoff (the glassmorphism look is independent of accent color). Instead,
ship all upstream variants verbatim and let the user swap by editing one line
in `metadata.desktop`. This is a deliberate departure from the arche
convention that visual configs render from the theme engine.

**Multi-monitor:** SDDM's X11 greeter places the login on the primary monitor
automatically — no config needed, works the same docked or undocked. X11 is
fine here even though the user session is Wayland: SDDM only launches the
session, it does not dictate the display server the session uses.

**Security note:** SDDM runs its greeter as a dedicated `sddm` system user
(not root), then authenticates via PAM. The Qt6/QML runtime surface is larger
than greetd's Rust daemon, but only during the login window; once a session
starts, SDDM steps out of the way.

**Files touched:**
- `packages/hyprland.sh` — `greetd`/`greetd-regreet`/`cage` removed; `sddm`, `qt6-5compat`, `qt6-svg`, `qt6-virtualkeyboard`, `qt6-multimedia-ffmpeg` added
- `system/etc/greetd/` — deleted (config.toml, regreet.toml)
- `system/etc/sddm.conf.d/10-arche.conf` — new (X11 greeter, Theme.Current=silent)
- `vendor/sddm-silent/` — new vendored theme tree (~3.3 MB)
- `scripts/05-hyprland.sh` — installs theme via `cp`, removes the older eucalyptus-drop install dir if present, enables SDDM
- `tools/bin/arche-greeter` — deleted (D012 retired it, was lingering)

---

## D012 — regreet + cage replaces arche-greeter

**Date:** 2026-04-11
**Status:** Accepted

Replaced arche-greeter (custom Rust TUI) with greetd-regreet (GTK4 greeter) running inside
cage (minimal kiosk Wayland compositor).

**Why:** arche-greeter required ongoing maintenance as a custom binary. regreet and cage are
community-maintained packages in the Arch `extra` repo with no custom code to own.

**Security:** greetd daemon unchanged (Rust, minimal, no CVE history). cage runs a single
fullscreen app with no window management surface. regreet runs unprivileged inside cage.

**Deps:** greetd-regreet (4.6 MiB) + cage (62 KiB) + wlroots0.19 (1.6 MiB). GTK4 and all
other regreet deps already on system via satty/ripdrag. Net new: ~6.3 MiB.

**Config:** `system/etc/greetd/regreet.toml` — ember theme values (Bibata cursor, Papirus-Dark
icons, IBM Plex Sans font, Adwaita-dark GTK theme). Linked by `05-hyprland.sh`.

**Multi-user:** regreet shows a user dropdown natively, no extra config needed.

---

## D011 — arche-greeter replaces tuigreet

**Date:** 2026-04-03
**Status:** Accepted

Custom Rust TUI greeter built with ratatui, replacing the `greetd-tuigreet` AUR package.
Speaks greetd IPC directly via `greetd_ipc` crate. Ember-themed, ~670KB stripped binary.

Source: `~/projects/system/arche-bin/arche-greeter/` (separate git repo).
Binary deployed to: `~/arche/stow/hypr/.local/bin/arche/arche-greeter`
Build: `just build-greeter`

**Why:** tuigreet's UI is not customizable beyond CLI flags. arche-greeter gives full
control over layout, colors, and behavior. One less AUR dependency.

---

## D010 — greetd+tuigreet replaces SDDM, swaybg dropped

**Date:** 2026-04-03
**Status:** Accepted

**SDDM → greetd + tuigreet:** SDDM pulled in Qt dependencies solely for a login
screen. greetd is a minimal login daemon (~1MB) and tuigreet is a TUI greeter
that matches the TUI-first philosophy. Config at `system/etc/greetd/config.toml`.

tuigreet options: remembers last user + session, shows time, masked password
input with `·` characters, launches `uwsm start hyprland-uwsm.desktop`.

**swaybg removed:** swww was already the primary wallpaper daemon (animated
transitions, persistence across reboots). swaybg was kept as a "fallback" but
never used — autostart.conf killed it immediately. Removed from packages,
autostart, and arche-wallpaper script.

---

## D009 — Rofi replaces Walker+Elephant as app launcher

**Date:** 2026-04-03
**Status:** Accepted

Walker's UI was unsatisfactory and the elephant data-provider ecosystem added
12 AUR packages for functionality rofi provides natively.

**Rofi-wayland** runs in combi mode by default: one search bar searches apps (drun),
commands (run), and open windows simultaneously — Spotlight-style UX.
Additional modes available via Tab: filebrowser, SSH.

**What rofi replaces:**
- `walker-bin` + 11 `elephant-*` AUR packages → 1 pacman package (`rofi-wayland`)
- Clipboard history: `cliphist list | rofi -dmenu` (cliphist was already installed)
- Window switching: `rofi -show window` (new `Super+Tab` binding)

**Theming:** rasi file rendered from Ember template (`templates/rofi/theme.rasi.tmpl`).
Full CSS-like control over layout, colors, fonts, border-radius.

**Hyprland integration:** layerrules provide blur + fade animation on the rofi layer.

---

## D008 — Popup convention: `--class popup` for floating TUI windows

**Date:** 2026-03-28
**Status:** Accepted

All TUI apps that should open as centered floating popups use `kitty --class popup`.
Three windowrules in `windows.conf` match `^popup$` on class and apply float + size + center.

**Why `--class` not `--title`:** Hyprland v0.54 static effects (`float`, `size`, `center`)
were unreliable with `match:title` regex in testing. `match:class` with exact match works
consistently. Using a single class means one set of rules covers all popup TUIs.

**Why not per-app rules:** The previous approach required 3 rules per app (15+ lines for 5 apps).
The popup convention is zero-touch — add `--class popup` to any keybinding, done.

**Syntax notes for Hyprland v0.54+:**
- Effects use `on` not `1`: `float on`, `center on`
- Named `windowrule {}` blocks require `name =` as the first key
- `match:class` / `match:title` take RE2 regex
- Static effects evaluate once at window creation against initial class/title

---

## D007 — arche-legion: Rust TUI for laptop management

**Date:** 2026-03-28
**Status:** Accepted

`tools/legion/` contains a Ratatui-based TUI that replaces Lenovo Vantage functionality.
Reads/writes sysfs knobs exposed by `ideapad_laptop` and `lenovo_wmi_gamezone` kernel modules.

**Controls:** battery conservation mode, fan mode, camera kill switch, USB charging,
Fn lock, platform profile (low-power/balanced/performance/max-power).

**Auth:** checks sudo credential cache on startup. If not cached, shows an in-TUI
password modal with masked input and success/failure feedback. Uses `sudo -S -v` to
validate, then `sudo -n tee` for subsequent writes.

**Build:** `just build-legion` compiles release binary and copies to stow path.
Binary is 615KB (stripped, LTO, opt-level z).

---

## D006 — Security: Tailscale-only services, NextDNS, nftables cleanup

**Date:** 2026-03-25
**Status:** Accepted

**Services routed through Tailscale:** Syncthing and KDE Connect no longer have
dedicated UFW port rules. Instead, `ufw allow in on tailscale0` permits all
traffic on the Tailscale mesh interface (already WireGuard-encrypted). This
reduces the attack surface — no LAN-exposed service ports.

**DNS:** NextDNS via systemd-resolved with DNS-over-TLS. Config lives at
`system/etc/systemd/resolved.conf`, symlinked by `02-security.sh`.
`/etc/resolv.conf` points to the resolved stub.

**nftables:** Explicitly disabled. UFW is the sole firewall manager. The prior
nftables-vs-ufw conflict (X1) is fully resolved — `02-security.sh` stops and
disables nftables.service before configuring UFW.

**Kernel hardening:** sysctl drop-in at `system/etc/sysctl.d/99-arche-hardening.conf`.
SYN cookies, reverse path filtering, ICMP redirect rejection, kernel pointer
hiding, ptrace restriction, BPF hardening, symlink/hardlink protection.
All boolean switches — zero performance cost.

**Lid close:** Explicit logind drop-in at `system/etc/systemd/logind.conf.d/99-arche.conf`.
Suspend on lid close (battery + AC), ignore when docked. Hypridle locks
screen before sleep via `loginctl lock-session`.

**MAC randomization:** Configured at runtime for whichever network manager is
present (NetworkManager or iwd). Randomizes WiFi MAC per-network so hardware
ID isn't broadcast to every AP you scan.

**AMD microcode:** `amd-ucode` added to `packages/base.sh`. Patches CPU
vulnerabilities (Spectre, Meltdown) at early boot.

**Not included (by design):**
- No SELinux/AppArmor — poor Arch support, not worth the friction.
- No auditd — compliance tool, overhead without value on a personal machine.
- No unattended updates — manual `pacman -Syu` preferred.
- LUKS encryption is install-time, not managed by bootstrap.
- USBGuard — auto-installed and configured; initial policy generated from
  currently connected devices. New devices blocked by default.

---

## D005 — Template vs stow: which layer owns what

**Date:** 2026-03-13
**Status:** Accepted

Decision rule: **does this config contain colors, fonts, or sizes?**

- **No** → stow package only (`stow/<name>/`). Symlinked as-is.
- **Yes** → behavior parts in stow, visual parts in `templates/`. `theme.sh`
  renders the template to `~/.config/` (generated output, gitignored).
- **All visual, no behavior** → template only (e.g. mako).

Concrete mapping:

| Component  | stow/ (behavior)                 | templates/ (visual)              |
|------------|----------------------------------|----------------------------------|
| fish       | config.fish, conf.d/, functions/ | conf.d/theme.fish.tmpl           |
| kitty      | kitty.conf (behavior)            | theme.conf.tmpl                  |
| starship   | starship.toml (modules, format)  | —                                |
| mpv        | mpv.conf, input.conf, scripts    | —                                |
| hypr       | hyprland.conf (keybinds, rules)  | colors.conf.tmpl, hyprlock-colors.conf.tmpl |
| waybar     | config.jsonc (modules, layout)   | style.css.tmpl                   |
| syshud     | config.conf (layout, timeout)    | style.css.tmpl                   |
| mako       | —                                | config.tmpl                      |
| rofi       | config.rasi (behavior)           | theme.rasi.tmpl                  |
| yazi       | yazi.toml, keymap.toml           | theme.toml.tmpl                  |
| btop       | btop.conf (behavior)             | arche.theme.tmpl                 |
| tmux       | tmux.conf (behavior)             | colors.conf.tmpl                 |
| gtk        | settings.ini (behavior)          | gtk.css.tmpl (gtk-4.0)           |
| nvim       | init.lua, plugins/ (all)         | — (excluded, uses catppuccin/nvim) |
| qt6ct      | qt6ct.conf (behavior)            | — (TODO: templatize Ember.conf)  |
| kvantum    | —                                | — (TODO: templatize Ember.kvconfig) |
| pipewire   | pipewire.conf (behavior)         | —                                |
| wireplumber| wireplumber.conf (behavior)      | —                                |
| vivaldi    | (browser flags)                  | —                                |
| elephant   | (walker data provider)           | —                                |

---

## D004 — Stow packages under `stow/` directory

**Date:** 2026-03-13
**Status:** Accepted

All GNU Stow packages live under `stow/` instead of the repo root. This keeps
the root clean for infrastructure files (scripts, packages, templates, themes,
docs) and avoids clutter as more components are added.

Stow commands use `-d stow -t $HOME`:

```bash
stow -d "$ARCHE/stow" -t "$HOME" fish
```

**Alternatives considered:**
- Root-level packages (prior approach) — gets noisy past 5-6 packages.
- Grouped by category (`stow/shell/`, `stow/desktop/`) — overkill for ~10
  packages, complicates stow commands, categories become debatable.

---

## D003 — Fish shell replaces Zsh

**Date:** 2026-03-13
**Status:** Accepted

Switching from Zsh + zinit to Fish + fisher.

**Why:**
- Fish has sane defaults out of the box (syntax highlighting, autosuggestions,
  completions) without needing a plugin manager to bolt them on.
- `conf.d/` auto-sourcing and lazy `functions/` loading is a clean native
  pattern — no need for the manual module-loading loop we had in `.zshrc`.
- Abbreviations (`abbr`) expand inline so full commands appear in history,
  making history search more useful.

**What carries over from zsh:**
- All aliases (filesystem, git, tmux, general)
- Media functions (compress, transcode, img convert)
- PATH management and exports
- Tool integrations (fnm, fzf, starship, zoxide)
- SSH agent setup
- local.fish for secrets (gitignored)

**What gets dropped:**
- zinit and all zsh plugins (replaced by fish builtins + fisher)
- devon() lazy loader (referenced pyenv + nvm, neither installed)
- gcloud integration (not on this machine)
- zsh-specific completions, options, keybindings (fish handles natively)
- `apt-fast` alias, Lenovo battery aliases (not applicable to current hardware)

---

## D002 — Three-layer config split

**Date:** 2026-03-13
**Status:** Accepted

Every config file belongs to exactly one of three layers: template (visual),
stow package (behavior), or generated output (never committed). This prevents
color values from leaking into behavior configs and makes theme switching a
single `envsubst` pass.

See [architecture.md](architecture.md) for full details.

---

## D001 — Ember as default theme (was Catppuccin Mocha)

**Date:** 2026-03-13, **Updated:** 2026-03-25
**Status:** Accepted (revised)

Ember is the active theme (`themes/ember.sh`). Warm amber (#c9943e) on deep
charcoal (#13151c). Originally started as Catppuccin Mocha, replaced with a
custom palette. All color values defined once in the theme file and consumed
via templates. Adding a new theme means creating a new shell file satisfying
`themes/schema.sh`. See `docs/theme-standard.md` for the full specification.
