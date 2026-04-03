# Decision Log

Each entry records a significant choice, the reasoning, and any trade-offs.
Newest entries at the top.

---

## D011 — arche-greeter replaces tuigreet

**Date:** 2026-04-03
**Status:** Accepted

Custom Rust TUI greeter built with ratatui, replacing the `greetd-tuigreet` AUR package.
Speaks greetd IPC directly via `greetd_ipc` crate. Ember-themed, ~670KB stripped binary.

Source: `~/stuff/personal/arche-bin/arche-greeter/` (separate git repo).
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
