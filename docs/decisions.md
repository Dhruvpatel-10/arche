# Decision Log

Each entry records a significant choice, the reasoning, and any trade-offs.
Newest entries at the top.

---

## D021 — KDE Plasma replaces Hyprland as desktop environment

**Date:** 2026-04-16
**Status:** Accepted
**Reverses:** D008 (popup convention now uses KWin rules, not Hyprland windowrules)
**Supersedes:** D009 (Rofi replaced by KRunner), D015 (hyprpaper replaced by Plasma Wallpaper), D019 (SwayOSD replaced by KDE OSD)

Switching from a minimal tiling Wayland compositor (Hyprland) to a full desktop
environment (KDE Plasma 6, Wayland session). KDE Plasma provides an integrated
desktop with compositor, panel, notifications, launcher, lock screen, power
management, OSD overlays, and wallpaper management out of the box — replacing
eight separate tools that were individually configured and maintained.

**What replaces what:**

| Hyprland stack           | KDE Plasma equivalent      |
|--------------------------|----------------------------|
| Hyprland (compositor)    | KWin (compositor)          |
| Waybar (status bar)      | KDE Panel                  |
| Mako (notifications)     | KDE Notifications          |
| Rofi (app launcher)      | KRunner                    |
| hyprlock (lock screen)   | kscreenlocker              |
| hypridle (idle/power)    | Powerdevil                 |
| hyprpaper (wallpaper)    | Plasma Wallpaper           |
| SwayOSD (volume/brightness OSD) | KDE OSD              |
| grim + slurp + satty (screenshots) | Spectacle          |
| xdg-desktop-portal-hyprland | xdg-desktop-portal-kde |
| uwsm (session wrapper)  | Plasma session (native)    |

**What stays unchanged (compositor-agnostic):**
- Fish + Atuin + Fisher + Starship (shell stack)
- Kitty (terminal)
- Neovim / LazyVim (editor)
- PipeWire + WirePlumber (audio)
- Ember theme system (schema.sh, theme.sh, templates for kitty/btop/tmux/etc.)
- NVIDIA driver stack (nvidia-open-dkms)
- Security layer (ufw, sysctl, USBGuard, Tailscale, NextDNS)
- arche-legion TUI (hardware management)
- mpv, zathura, btop, tmux, vivaldi (applications)
- GNU Stow convention, three-layer config split, package registry

**SDDM:** Kept as login manager — SDDM is the native display manager for KDE Plasma.
Switched from vendored SilentSDDM theme (glassmorphism, see D013) to the Breeze theme
that ships with KDE Plasma. `vendor/sddm-silent/` is retained in git history but no
longer deployed. SDDM config updated in `system/etc/sddm.conf.d/10-arche.conf`.

**Stow changes:**
- Removed: `stow/hypr/`, `stow/waybar/`, `stow/rofi/`, `stow/swayosd/`,
  `stow/hyprland-preview-share-picker/`
- Added: `stow/kde/` (KDE Plasma + KWin config, including KWin window rules)

**Template changes:**
- Removed: `templates/hypr/`, `templates/waybar/`, `templates/swayosd/`,
  `templates/hyprland-preview-share-picker/`, `templates/rofi/`, `templates/mako/`
- Added: `templates/kde/Ember.colors.tmpl` (KDE color scheme rendered and applied
  via `plasma-apply-colorscheme`)
- Remaining templates (kitty, btop, tmux, gtk, zathura, fish, glow, starship, mpv,
  qt6ct, legion) are compositor-agnostic.

**Package changes:**
- `packages/hyprland.sh` renamed to `packages/kde.sh`
- Hyprland-specific packages removed (hyprland, hyprlock, hypridle, hyprpaper,
  hyprpolkitagent, xdg-desktop-portal-hyprland, uwsm, swayosd, mako, grim, slurp,
  satty, rofi-wayland, waybar)
- `packages/kde.sh` is intentionally empty — the `plasma` group + `sddm` are
  installed at Arch-install time (via archinstall or pacstrap), not by bootstrap.
  `scripts/05-kde.sh` verifies `plasma-desktop`, `kwin`, `sddm` are present and
  fails fast if not.
- Hyprland compositor-agnostic leftovers also removed: `cliphist` (Klipper
  replaces it) and `brightnessctl` (Powerdevil handles brightness keys natively).
- `wl-clipboard` moved from `packages/kde.sh` to `packages/base.sh` — it's a
  general Wayland CLI, not KDE-specific.

**Script changes:**
- `scripts/05-hyprland.sh` renamed to `scripts/05-kde.sh`
- SilentSDDM theme installation removed; SDDM configured with Breeze theme
- `scripts/07-bar.sh` and `scripts/08-notifications.sh` deleted (KDE Panel and
  KDE Notifications are built into Plasma). Subsequent scripts renumbered:
  `09-runtimes`→`07`, `10-apps`→`08`, `11-stow`→`09`, `12-appearance`→`10`.
- `packages/bar.sh` and `packages/notifications.sh` deleted.

**Popup convention (D008 update):**
- `kitty --class popup` still works for floating TUI windows
- Window matching now uses a KWin window rule instead of Hyprland windowrules
- Rule managed via `stow/kde/` or KDE System Settings

**Why:**
- Reduced maintenance burden — eight individually configured tools replaced by
  one integrated desktop environment
- Better multi-monitor support, drag-and-drop, system tray, and desktop integration
- Native Qt6 desktop (already had Qt6 deps on system via Kvantum, qt6ct, etc.)
- KDE Plasma 6 on Wayland is mature and performant as of 2026

---

## D020 — AGS v3 / Astal evaluated for future widget replacement

**Date:** 2026-04-13
**Status:** Deferred
**Depends on:** D019 (current OSD stack works, no urgency)

Evaluated AGS (Aylur's GTK Shell) v3 + Astal as a unified TypeScript framework
to replace Waybar + SwayOSD + Mako with a single codebase.

**What it is:**
- AGS v3.1.2 (latest, Apr 2026) — CLI scaffolding + esbuild bundler for GJS
- Astal — set of C/Vala GObject libraries for system bindings (battery, bluetooth,
  network, tray, hyprland IPC, wireplumber, mpris, notifd, etc.)
- Gnim — SolidJS-inspired reactive JSX layer for GJS (signals, effects, no vDOM)
- Runtime: GJS (GNOME JavaScript, SpiderMonkey engine) + GTK4 + gtk4-layer-shell

**Architecture:**
- Write `.tsx` files with JSX → esbuild transpiles → GJS executes
- Lowercase JSX tags = GTK4 intrinsics (`<window>`, `<box>`, `<label>`)
- Uppercase = custom components
- Reactivity: `createState`, `createBinding`, `createComputed`, `createEffect`
- Layer shell windows via gtk4-layer-shell (same protocol Waybar uses)
- `ags bundle` produces a self-contained Bash script with embedded JS
- `ags run ./file.tsx` for development without bundling

**What it replaces:**
- Status bar (Waybar) — window anchoring, tray, workspaces, audio, network modules
- Notifications (Mako) — `libastal-notifd` implements freedesktop notification spec
- OSD overlays (SwayOSD) — custom popup windows with layer shell positioning
- Proof: HyprPanel and Matshell are real-world AGS projects replacing all three

**Animation capabilities:**
- CSS transitions (limited set: opacity, background-color, color, margin, padding)
- `Gtk.Revealer` for show/hide animations (slide, crossfade)
- `Gtk.Stack` for animated child transitions
- `Adw.Animation` / `Adw.SpringAnimation` (imperative, via libadwaita)
- JS-driven frame-by-frame via `GLib.timeout_add` or `createPoll`
- No built-in animation DSL — you compose from GTK4 primitives

**Theming:**
- GTK CSS (`.css` or `.scss` via dart-sass)
- Runtime swap: `app.apply_css(newCss)` / `app.reset_css()`
- No native shell variable reading — would still use envsubst templates or
  JS-side env var reading to integrate with arche theme system
- `ags inspect` opens GTK Inspector for live CSS debugging

**Installation (Arch, AUR only):**
- `aylurs-gtk-shell` (v3.1.2) — main package
- `libastal-meta` (v1-8) — pulls all 17 Astal service libraries
- All are `-git` AUR packages, no stable releases in official repos
- Build deps: `go`, `meson`, `npm`
- Runtime deps: `gjs`, `gtk4`, `gtk4-layer-shell`, `gobject-introspection`
- Optional: `dart-sass` (SCSS), `blueprint-compiler`

**Why deferred:**
- AUR-only with 17+ packages, all `-git` — maintenance burden
- Single-developer project (Aylur) — bus factor of 1
- AUR packaging has had breakage (missing GIR typelibs, build chain issues)
- Would require ~500-1000 lines of TypeScript to replicate current functionality
- GJS runtime is heavier than native C tools (higher memory baseline)
- Current stack (Waybar + SwayOSD + Mako) is working and just got consolidated
- Bun `--compile` is NOT viable — GJS runtime required for GTK4 bindings

**When to revisit:**
- When the current stack hits a design/animation wall that can't be solved with CSS
- When AGS packages land in `extra` (unlikely near-term) or packaging stabilizes
- When there's a concrete UI vision that needs programmatic widget composition

**Reference projects:**
- AGS repo: github.com/aylur/ags
- Astal repo: github.com/aylur/astal
- HyprPanel: AUR `ags-hyprpanel-git`
- Matshell: github.com/Neurarian/matshell

---

## D019 — SwayOSD replaces syshud as OSD overlay

**Date:** 2026-04-13
**Status:** Accepted

Replaced syshud (AUR, passive PipeWire/backlight listener) with SwayOSD (pacman
`extra`, active client-server model) for volume, brightness, caps/num lock OSD.

**Why:**
- syshud was too generic — plain rectangle, no icon, no mute indicator, no lock-key support
- SwayOSD provides: volume/brightness bars with icons, mute state, caps/num lock indicators,
  mic mute, segmented brightness, percentage labels
- SwayOSD is in `extra` (not AUR) — better maintained, no PKGBUILD risk
- Client-server model: `swayosd-client` both performs the action AND shows OSD,
  eliminating the need for separate wpctl/brightnessctl calls in keybindings

**Architecture:**
- `swayosd-server` — daemon launched at compositor start (autostart.conf)
- `swayosd-client` — keybinding trigger that sends commands to server
- GTK4 layer-shell surface, namespace `swayosd` (overlay level 3)
- Config: TOML at `~/.config/swayosd/config.toml` (behavior → stow)
- CSS: GTK4 CSS at `~/.config/swayosd/style.css` (visual → template)

**Files changed:**
- `packages/hyprland.sh` — removed syshud from AUR_PKGS, added swayosd to PACMAN_PKGS
- `stow/swayosd/.config/swayosd/config.toml` — new (server settings: margin, max vol, min brightness)
- `templates/swayosd/style.css.tmpl` — new (glassmorphism pill, theme vars)
- `stow/hypr/.config/hypr/media.conf` — keybindings now use swayosd-client
- `stow/hypr/.config/hypr/autostart.conf` — `exec-once = swayosd-server`
- `stow/hypr/.config/hypr/looknfeel.conf` — layerrules namespace `swayosd` (blur, xray)
- `scripts/lib.sh` — theme reload: kill+restart swayosd-server

**Keybinding changes:**
- Volume: `wpctl` → `swayosd-client --output-volume raise/lower/mute-toggle`
- Brightness: `brightnessctl` → `swayosd-client --brightness raise/lower`
- Keyboard backlight: unchanged (brightnessctl, SwayOSD doesn't handle kbd devices)
- New: Caps_Lock → `swayosd-client --caps-lock`, Num_Lock → `swayosd-client --num-lock`

**CSS design:**
- Frosted glass pill (border-radius: 999px)
- Background: `alpha(COLOR_BG_ALT, 0.78)` — opaque enough to read over any content
- Compositor blur via layerrules provides the frosted effect behind
- Accent-colored icon, bold label, accent fill on progress bar
- Drop shadow + inset highlight for depth

**Removed:**
- `stow/sys64/` — deleted (syshud stow package)
- `templates/sys64/` — deleted (syshud CSS template)
- syshud from AUR_PKGS (packages/hyprland.sh now has `AUR_PKGS=()`)

---

## D018 — Fish restored, bash + ble.sh + bash-preexec removed

**Date:** 2026-04-12
**Status:** Accepted
**Reverses:** D016 (and supersedes D017, which was a partial mitigation)
**Restores:** D003 (Fish shell, with one tweak — fisher from upstream curl, not AUR)

Switching the interactive and login shell back from Bash to Fish. The bash
stack (`stow/bash/`, `vendor/blesh/`, `vendor/bash-preexec/`, `tools/bin/carapace`,
bash-completion sourcing) is fully removed. fish + fisher + atuin replaces it.

**Why D016 didn't survive 24 hours:**
- D016 estimated a "~5% UX gap" between fish and bash+ble.sh. The actual gap
  was much larger and surfaced as continuous, daily friction:
  - carapace's bash bridge errored on partial input (`read: \`': not a valid
    identifier`) on every keystroke. Removed in D017 — but the underlying
    issue was that ble.sh + programmable completion is a fragile coupling.
  - ble.sh's multiline paste mode (MULTILINE edit, `C-j: run` hint) confused
    every paste of more than one line.
  - ble.sh's word-deletion widgets (`cword`/`eword`/`uword`) split on shell
    metacharacters and felt random for Ctrl+Backspace.
  - Kitty's keyboard protocol (`C-DEL`) vs legacy (`C-h`) for the same
    physical key meant binding ctrl+backspace correctly took multiple tries.
  - Inline ghost suggestions pulled stale or context-irrelevant lines from
    history because ble.sh's history source has no command-aware filter.
- Fish ships all of this **as defaults**, with no .blerc tuning, no widget
  bindings, no carapace bridge, no kitty keyboard-protocol gymnastics.

**What stays from D016:**
- The supply-chain principle: no AUR PKGBUILDs for shell-layer tooling.
  - `fish` is from the `extra` repo (clean, audited by Arch maintainers).
  - `fisher` is **installed from upstream curl**, not from AUR. The official
    one-liner downloads `fisher.fish` directly into
    `~/.config/fish/functions/`, exactly as upstream documents. This avoids
    AUR PKGBUILD execution, matching D016's vendoring intent without the
    overhead of vendoring fisher itself (it's a 700-line fish script that
    self-updates).
- atuin (extra repo, SQLite history, `Ctrl-R`) — kept unchanged from D016.
- starship, kitty, tmux, fnm, uv, zoxide, ssh-agent — all shell-agnostic,
  unchanged.

**What we lose vs D016:**
- Interactive == script shell. Fish is not POSIX, so one-liner pastes from
  bash documentation may need translation. This was D016's biggest argument
  in favor of bash, but in practice the friction of using bash interactively
  outweighed the friction of occasional fish translation for one-liners.

**Layout:**
- `stow/fish/` — restored from commit `4ed5d6d^` (the commit immediately
  before D016 deleted it). Same `config.fish`, `conf.d/`, `functions/`,
  `fish_plugins`, `local.fish.template` as the original D003 setup.
- `templates/fish/conf.d/theme.fish.tmpl` — restored. Renders fish color
  variables from the active theme palette (`fish_color_*`).
- `stow/bash/` — deleted entirely.
- `vendor/blesh/`, `vendor/bash-preexec/` — deleted entirely.
- `tools/bin/carapace` and its `.source` manifest — already removed in D017.
- `packages/shell.sh` — `bash`, `bash-completion` removed. `fish` added.
  `atuin`, `starship`, `kitty`, `tmux` unchanged.
- `scripts/06-shell.sh` — restored to the pre-D016 fish flow: install fish,
  add to `/etc/shells`, `chsh`, stow, render theme template, install fisher
  via upstream curl, run `fisher update`.

**Test changes:**
- `tests/test_lint.sh` — `bash -n stow/bash/...` and `vendor/blesh,
  bash-preexec/...` checks replaced with `fish --no-execute stow/fish/*.fish`.
- `tests/test_integration.sh` — ble.sh / bash-preexec presence checks and
  the bash-completion availability check replaced with fish runnability
  check and fisher-installed check.

**Operator tasks on already-installed machines:**
```
# 1. Install fish + change shell
sudo pacman -S --needed fish
chsh -s "$(command -v fish)"

# 2. Stow fish, render theme, install fisher
just shell

# 3. Tear down bash stack from $HOME
stow -D -d /opt/arche/stow -t "$HOME" bash 2>/dev/null || true
rm -f ~/.bashrc ~/.bash_profile ~/.bash_logout ~/.blerc
rm -rf ~/.bash

# 4. Open a new kitty window. You should land in fish.
```

**Consequences:**
- `.claude/rules/secrets.md` updated to reference `~/.config/fish/local.fish`
  again (gitignored).
- `.gitignore` reverts `local.bash` → `local.fish`.
- `CLAUDE.md`, `README.md`, `Justfile`, `bootstrap.sh`, `docs/architecture.md`,
  `docs/status.md`, `packages/CLAUDE.md`, `helpers/migrate-to-opt.sh` all
  updated to reflect the fish stack.
- D016 and D017 stay in the log as historical record. The lessons:
  bash+ble.sh in 2026 is still not a drop-in for fish, and the supply-chain
  win of vendoring is real but not worth multi-hour debugging sessions.

---

## D017 — Carapace removed, bash-completion takes over

**Date:** 2026-04-12
**Status:** Accepted
**Amends:** D016 (carapace was part of original D016 stack)

Removing `carapace-bin` entirely. Per-tool completions now come from
`bash-completion` (extra repo), which was already installed but unsourced.

**Why:**
- carapace's bash bridge (`_carapace_completer`) shells out per keystroke and
  emits `bash: read: \`': not a valid identifier` errors mid-typing on partial
  input. ble.sh's auto-complete preview was triggering it on every character,
  spamming the prompt with errors and a popup that pasted multi-line garbage.
- The friction was severe enough that day-to-day shell use became unpleasant
  within 24h of D016 landing — far beyond the "5% UX gap" estimate in D016.
- carapace's value was the long tail of tool completions (uv, deno, k6, etc).
  bash-completion covers the high-value 80% natively (git, docker, systemd,
  ssh, kubectl, pacman, ~200 tools) without the bridge fragility. The long
  tail falls back to filename completion, which is acceptable.
- Net supply-chain win: one fewer vendored binary (65 MB Go static binary +
  pinned-commit manifest + audit burden) in exchange for one extra-repo
  package that already shipped on the system.

**What changed:**
- Deleted: `tools/bin/carapace`, `tools/bin/.carapace.source`,
  `stow/bash/.bash/conf.d/70-carapace.sh`.
- `stow/bash/.bashrc` now sources `/usr/share/bash-completion/bash_completion`
  before bash-preexec.
- `scripts/06-shell.sh` no longer symlinks the carapace binary.
- `tests/test_lint.sh` lost the carapace presence check.
- `tests/test_integration.sh` swaps the carapace binary check for a
  bash-completion availability check.
- `.blerc` keeps `complete_auto_complete_opts=syntax-disabled` and the
  `_ble_complete_auto_source=(history)` override — these remain useful as
  defense in depth, even though carapace is gone.

**Consequences:**
- ble.sh's Tab-triggered completion still works via bash-completion.
- Inline ghost suggestion remains fish-like (history only).
- D016's three pillars (supply-chain minimalism, interactive==script,
  vendored stack) are intact and slightly improved.
- If carapace's coverage is missed in practice, the path forward is to
  install it from `extra` (not vendor it) and add a thin shim that *doesn't*
  pipe through ble.sh's auto-complete preview.

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
  it skips the system-level scripts (00-05, 07-08, 10) because pacman packages
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
| swayosd    | config.toml (server settings)    | style.css.tmpl                   |
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
