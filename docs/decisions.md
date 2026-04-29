# Decision Log

Each entry records a significant choice, the reasoning, and any trade-offs.
Newest entries at the top.

---

## D030 — Drop USBGuard

**Date:** 2026-04-28
**Status:** Accepted
**Reverses:** D003-era inclusion of USBGuard in the security layer.

USBGuard blocked every hotplug device by default and offered no in-session
prompt — phones plugged for MTP file transfer were silently denied, surfacing
only as repeated `Device.Insert`/`Device.Remove` lines in the journal as the
USB stack retried. The recovery path required `usb-inspect` or
`usbguard allow-device -p <N>` per device, with no UX integration into the
Quickshell notification stack. For a single-user laptop that already encrypts
the disk, locks the screen, and runs a default-deny firewall, the friction
exceeded the threat model: USBGuard's value is in shared/multi-user
workstations and kiosk deployments where unattended ports get probed.

Removed: package `usbguard`, the policy-generation block in `02-security.sh`,
the `usb-inspect` helper at `system/usr/local/bin/`, the README/CLAUDE/status
references. `firejail` and `fail2ban` stay; LUKS, sysctl hardening, SSH
key-only, and the rest of the layer are unchanged.

If a future host needs USB lockdown (shared machine, traveling, hostile
environment), reintroduce alongside `usbguard-notifier` (AUR) so the user gets
a libnotify popup with allow/block actions on every plug — silent block was
the actual UX failure, not the policy itself.

---

## D029 — Vendor Quickshell source into `/opt/arche/shell/`

**Date:** 2026-04-19
**Status:** Accepted
**Supersedes:** D023's external-repo arrangement (the rest of D023 — "Hyprland restored, Quickshell replaces KDE+Waybar" — still stands)

The QML source for the Quickshell panel (bar, control-center, notifications,
toasts, OSD, clipboard picker, calendar, services) used to live in a separate
GitHub repo and was cloned per-user to `~/projects/system/arche-shell/` by
`07-panel.sh`, with `~/.config/quickshell/` symlinked to that clone.

Moved it into `/opt/arche/shell/`, versioned alongside the rest of the repo.
`07-panel.sh` now just symlinks `~/.config/quickshell/ → /opt/arche/shell/` for
every user — no clone, no `git pull`, no drift.

**Why:**
- **Per-user clones drifted.** A second user (leanscale) got a stale checkout
  because local work on stark's clone was never pushed upstream. Every user
  edit required a push/pull dance across machines.
- **No real reason to be external.** The panel is tightly coupled to the hypr
  keybinds, theme tokens, and `arche-popup`/`arche-screenshot` scripts that
  already live in `/opt/arche`. Cross-repo commits to change a keybind and the
  corresponding panel button were already awkward.
- **`/opt/arche` is already the shared workspace.** Mode `drwxrwsr-x stark:users`
  with the setgid bit — anyone in `users` can edit. Tools binaries, system
  hooks, and profile drop-ins all live here; the shell source fits the same
  pattern.
- **Hot-reload still works.** Quickshell watches file mtimes — ownership and
  path don't matter. Editing `/opt/arche/shell/components/Bar.qml` hot-reloads
  the bar instantly for every user whose quickshell points at it.

**What changed:**
- `/opt/arche/shell/` — populated with the QML source (components/, osd/,
  services/, theme/, docs/, shell.qml, etc.). `.git` stripped; now tracked
  directly by the arche repo.
- `scripts/07-panel.sh` — clone/pull logic removed; just symlinks
  `~/.config/quickshell/ → $ARCHE/shell/`.
- `CLAUDE.md` — "External Shell" section renamed to "Quickshell Panel Source
  (`shell/`)"; Desktop Stack bullet updated; Repository Structure gains a
  `shell/` entry.

**Migration for existing users:** first `07-panel.sh` run repoints the symlink
from the old clone to `/opt/arche/shell/`. `~/projects/system/arche-shell/`
and the `Dhruvpatel-10/quickshell` GitHub repo are now orphaned — safe to
archive or delete whenever the user wants. Nothing in the arche repo
references them anymore.

**Trade-off accepted:** the original GitHub repo's commit history is not
preserved inside `/opt/arche`. It's still at
<https://github.com/Dhruvpatel-10/quickshell> if needed; future history
accrues in the arche repo.

---

## D028 — revert to `hyprland-preview-share-picker` (AUR)

**Date:** 2026-04-19
**Status:** Accepted
**Reverses:** D027

Undid D027. The custom `arche-share-picker` binary kept hitting the xdph picker
contract from the wrong direction — each bug we fixed revealed another edge case
(missing `[SELECTION]` prefix, wrong window field, `select_child`/click race on
auto-focus, etc). The AUR picker already handles all of these correctly, ships
live monitor/window previews via `wlr-screencopy-v1` + `hyprland-toplevel-export-v1`,
and is production-tested.

**Why:**
- The xdph protocol is tighter than it looks (`[SELECTION]{flags}/{payload}`
  prefix mandatory; window payload is the toplevel id decimal, not the address;
  `r` flag controls token persistence). Easy to get one of these subtly wrong.
- Live previews require a Tokio runtime + `wayland-client` + `wayland-protocols-wlr`
  + `memfd` + `image` crates — ~600 LOC for something the AUR picker already does.
- Chasing parity with upstream is a bad use of time when one `paru -S` gets it.

**Trade-off accepted:** one AUR dep returns to the stack. The rest of the system
is still pacman-only.

**What changed:**
- `packages/hyprland.sh` — `gtk4-layer-shell` removed from PACMAN_PKGS; AUR_PKGS
  now contains `hyprland-preview-share-picker-git` (installs gtk4-layer-shell as
  a transitive runtime dep).
- `stow/hyprland-preview-share-picker/` — restored (AUR picker's config.yaml).
- `templates/hyprland-preview-share-picker/style.css.tmpl` — restored (Ember CSS).
- `stow/hypr/.config/hypr/xdph.conf` — `custom_picker_binary =
  hyprland-preview-share-picker`.
- `scripts/05-hyprland.sh` — `stow_pkg hyprland-preview-share-picker` restored.
- `scripts/lib.sh` — theme-reload case renamed.
- `tools/bin/arche-share-picker` + `system/usr/local/bin/arche/arche-share-picker`
  + `templates/arche-share-picker/` — all deleted.

The external Rust source repo at `~/projects/system/arche-share-picker/` is
retained for historical reference but is no longer wired into arche.

---

## D027 — arche-share-picker replaces hyprland-preview-share-picker

**Date:** 2026-04-19
**Status:** Accepted
**Supersedes:** D023 (which chose hyprland-preview-share-picker-git from AUR)

Replaced the AUR-only screen-share source picker with `arche-share-picker`, a
custom binary built in Rust and shipped via the `tools/bin/` convention.

**Why:**
- Zero AUR dependencies: `hyprland-preview-share-picker-git` was the sole AUR
  package in the entire stack; removing it makes the full install pacman-only.
- Fully pacman-tractable runtime: only `gtk4` (already a transitive dep) and
  `gtk4-layer-shell` (added to `packages/hyprland.sh`).
- Ember-themed via the template engine: `templates/arche-share-picker/style.css.tmpl`
  is rendered by `theme.sh apply` exactly like every other visual component.
- Strong typing and tests are owned in the external source repo
  (`~/projects/system/arche-share-picker/`) — builds stay out of arche proper.
- Binary deployed via the standard `tools/bin/` → `system/usr/local/bin/arche/`
  symlink chain, picked up automatically by `link_system_all` in `00-preflight.sh`.

**What changed:**
- `tools/bin/arche-share-picker` — pre-built binary (1.3 MB).
- `system/usr/local/bin/arche/arche-share-picker` — symlink into tools/bin/.
- `templates/arche-share-picker/style.css.tmpl` — Ember-themed GTK4 CSS.
- `stow/hypr/.config/hypr/xdph.conf` — `custom_picker_binary = arche-share-picker`.
- `packages/hyprland.sh` — AUR_PKGS emptied; `gtk4-layer-shell` added to PACMAN_PKGS.
- `stow/hyprland-preview-share-picker/` — deleted (no stow config needed).
- `templates/hyprland-preview-share-picker/` — deleted (replaced by arche-share-picker template).

---

## D026 — `awww` replaces `hyprpaper` as the wallpaper daemon

**Date:** 2026-04-18
**Status:** Accepted
**Reverses:** D015 (hyprpaper over swww)

Flipped back to the swww-family daemon, but on its maintained successor.
LGFae archived the original `swww` GitHub repo in October 2025 and moved
development to `awww` on Codeberg; Arch replaced `swww` with `awww` in the
official repos in March 2026 (same upstream, new name — "An Answer to your
Wayland Wallpaper Woes" vs. "A Solution to…").

**Why swap back:**
- hyprpaper 0.8's rewrite broke both the flat `preload =` / `wallpaper =`
  config syntax and the `hyprctl hyprpaper` subcommand path (see D015).
  `arche-wallpaper` compensated by rewriting `~/.config/hypr/hyprpaper.conf`
  and restarting the daemon on every switch — a ~200 ms stall per change
  and a single point of failure if hyprpaper bumps its Hyprlang format again.
- awww keeps the stable socket IPC from swww: `awww img <path>
  --transition-type …`, no config file, no daemon restart. The CLI surface
  is identical to swww, so anything on the internet about swww applies.
- Smooth transitions (fade/grow/wipe/wave) that D015 dismissed as
  "nice-to-have" come free. Replaces our `cat > hyprpaper.conf + pkill -x
  hyprpaper + setsid -f hyprpaper` choreography with a single `awww img`.
- Compositor-agnostic. If another compositor appears alongside Hyprland
  (Niri, for instance — awww's README explicitly calls out `--namespace`
  support for it), the same wallpaper daemon works.

**What changed in the repo:**
- `packages/hyprland.sh` — `hyprpaper` → `awww` (still PACMAN_PKGS).
- `stow/arche-scripts/.local/bin/arche/arche-wallpaper` — fully rewritten:
  `ensure_daemon` checks `awww query`, starts `awww-daemon` with
  `setsid -f` if missing; `set_wallpaper` calls `awww img` with transition
  flags; current wallpaper tracked in `$XDG_CACHE_HOME/arche-wallpaper/current`
  (plain-text cache, no more awk-parsing of a config file).
- `stow/hypr/.config/hypr/autostart.conf` — comment updated; the single
  `exec-once = arche-wallpaper random` still does the work because
  `ensure_daemon` auto-starts `awww-daemon` on first call.
- Tunables via env (have sensible defaults): `ARCHE_WP_TRANSITION` (default
  `grow`), `ARCHE_WP_FPS` (60), `ARCHE_WP_DURATION` (1).
- Migration note: on an existing machine, `sudo pacman -Rns hyprpaper` after
  the upgrade — the package is not removed automatically. `hyprpaper.conf`
  under `~/.config/hypr/` becomes stale and can be deleted.

---

## D025 — Custom SDDM theme `arche` (minimal multiuser ember greeter)

**Date:** 2026-04-18
**Status:** Accepted
**Amends:** D023 (no-vendored-theme clause — vendored theme is back, surface stays small)

The Breeze fallback SDDM was never actually breeze — the `breeze` theme tree
is not installed on this machine, so SDDM has been falling back to its stock
greeter. Replaced it with a bespoke QML theme at
`system/usr/share/sddm/themes/arche/`, symlinked into
`/usr/share/sddm/themes/arche/` by `link_system_all`.

**Design brief:**
- Minimal, modern, multi-user first.
- Horizontal row of user cards (avatars as initials on a disc — robust across
  Qt versions, no shader-masking), selected card highlighted with the ember
  accent ring, arrow-key navigable.
- Password field below the selected user, amber focus ring, Enter to submit
  with a small pill submit button.
- Clock top-right (mono), hostname top-left.
- Bottom-left chips cycle session and keyboard layout; bottom-right circular
  buttons for shutdown / restart / suspend — each only shown if SDDM
  reports the action is available.
- Two-file palette: `theme.conf` holds colors/fonts/layout as flat keys that
  the QML reads via `config.*`. Values match `theming/themes/ember.sh` directly so
  the greeter visually continues the rest of the system.

**Why:**
- Login is the first surface the user sees after Plymouth (D024). Stock SDDM
  is functional but unstyled — the rest of the stack (Plymouth, Hyprland,
  Quickshell, hyprlock) is themed end-to-end, this was the one gap.
- A tiny single-directory QML theme is a much smaller surface than the old
  SilentSDDM tree D023 removed (~260 config keys, plugin import chain). This
  one is ~450 lines of QML across 6 files, no external imports beyond stock
  QtQuick.

**What changed in the repo:**
- `system/usr/share/sddm/themes/arche/` — `Main.qml`, `theme.conf`,
  `metadata.desktop`, and `components/` (`Clock`, `UserCard`, `PasswordField`,
  `Chip`, `IconButton`).
- `system/etc/sddm.conf.d/10-arche.conf` — `Current=breeze` → `Current=arche`.
- `scripts/05-hyprland.sh` — updated comment; the theme itself needs no
  special install step, `link_system_all` picks up the tree.
- `Justfile` — added `just sddm-preview` (runs `sddm-greeter-qt6 --test-mode`
  against the in-repo theme path for quick iteration without rebooting).

**Trade-off accepted:**
- Colors are baked literally into `theme.conf` against the ember palette. A
  future theme switch won't recolour the greeter until the conf is rendered
  too. If/when a second theme ships, promote `theme.conf` to a template and
  teach `theme_render` to output to `/usr/share/sddm/themes/arche/theme.conf`
  via sudo. Deferred until there's a second theme to justify the plumbing.

---

## D024 — Plymouth splash + TPM2 PIN unlock (systemd-boot + UKI + sd-encrypt)

**Date:** 2026-04-18
**Status:** Accepted

Pre-boot UI is now a Plymouth script-theme (`arche` — subtle lavender on
near-black with an **ARCHE** wordmark), and the LUKS root unlock flow can
bind to TPM2+PIN instead of a passphrase. The two changes land together
because either alone looks wrong: pretty-splash-without-TPM still gates on a
typed passphrase, and TPM-without-Plymouth drops you to a bare-TTY PIN prompt.

**Bootloader stays on systemd-boot.** The live system was already on
systemd-boot (not Limine, despite what CLAUDE.md claimed pre-D024 — fixed
in the same commit). Limine's branded menu is nicer if you linger, but with
a single default UKI entry and `timeout=0` you never see either bootloader
menu — it's firmware → Plymouth → desktop. For that flow, systemd-boot is
simpler (no AUR mkinitcpio hook, `bootctl update` on `pacman -Syu` is
automatic, UKIs auto-discovered from `/boot/EFI/Linux/`).

**The flow, end-to-end:**

1. Firmware loads `systemd-bootx64.efi` from the ESP.
2. systemd-boot discovers UKIs in `/boot/EFI/Linux/*.efi` (BLS Type #2),
   picks `arch-linux.efi`, loads it.
3. The UKI bundles kernel + initramfs + cmdline + splash. Kernel boots,
   `systemd` hook runs PID 1 in early userspace.
4. `kms` hook pulls the NVIDIA modules — framebuffer is now live.
5. `plymouth` hook starts `plymouthd` and registers it as a `systemd-ask-password`
   agent. The `arche` theme draws its background + wordmark + rule sprites.
6. `sd-encrypt` hook reads `/etc/crypttab.initramfs`, sees
   `root UUID=<…> - tpm2-device=auto`, and hands off to
   `systemd-cryptsetup@root.service`.
7. systemd-cryptsetup queries the TPM2; policy requires the PIN, so it
   calls `systemd-ask-password "Please enter PIN for root (nvme0n1p2):"`.
8. The ask-password broadcast reaches `plymouthd`, which calls the theme's
   `display_password_callback(prompt, bullets)`. Each keystroke updates the
   dot row; wrong PIN → `display_message_callback("Wrong PIN…")` sets the
   error flag and the next redraw uses dusty-rose dots.
9. PIN correct → TPM unseals the LUKS key → `cryptsetup open` succeeds →
   rootfs pivots → systemd transitions to the real root.
10. `plymouth-quit-wait.service` holds the splash until SDDM's greeter is
    drawn, then Plymouth fades out in a single cross-fade — no TTY flash.

**Why pre-rendered PNGs for the wordmark and dots.** Plymouth script themes
*can* call `Image.Text()` at runtime, which under the hood uses pango +
fontconfig + freetype inside the initramfs. That works when it works, and
silently falls back to Cantarell when it doesn't. The `arche` theme renders
the wordmark, rule, and dots as PNGs during `12-boot.sh` via ImageMagick, then
ships them into `/usr/share/plymouth/themes/arche/` where `mkinitcpio -P`
bakes them into the UKI. One less failure surface, deterministic output, and
the palette is hardcoded in one place (the script) — no runtime font-finding.
Tradeoff: changing the wordmark text means regenerating the PNG
(`just boot`), not editing a config string. That's fine — the wordmark is
a brand element, not a configurable knob.

**The palette.** Hand-picked, not from `theming/themes/ember.sh`. The desktop is
ember; the pre-boot identity is purple. Different on purpose — the splash is
a front door, not a room you spend time in.

- `#15131d` — backdrop
- `#c8bbdd` — wordmark (light lavender, soft)
- `#a08dc4` — accent: rule + PIN dots (muted mid-lavender)
- `#b88a9a` — error: dusty rose for wrong-PIN flash
- `#615572` (via Image.Text) — prompt text, dim enough to sit behind the dots

These are hardcoded in `tools/plymouth/arche/arche.script` and in the
ImageMagick render commands in `scripts/12-boot.sh`. Change one, change the
other.

**mkinitcpio HOOKS change.** Old: `base udev autodetect microcode modconf kms
keyboard keymap consolefont block encrypt filesystems fsck`. New (via
`/etc/mkinitcpio.conf.d/arche.conf` drop-in): `base systemd autodetect
microcode modconf kms keyboard sd-vconsole block plymouth sd-encrypt
filesystems fsck`. Four substitutions:
- `udev` → `systemd`: early userspace is pid-1 systemd, required for
  `systemd-cryptsetup`.
- `keymap` + `consolefont` → `sd-vconsole`: systemd-native console setup.
- `encrypt` → `sd-encrypt`: reads `/etc/crypttab.initramfs` and talks to
  `systemd-cryptsetup`, which in turn can use TPM2.
- `plymouth` inserted between `kms` and `sd-encrypt`: the framebuffer is up
  by the time Plymouth draws, and Plymouth's password agent is registered
  by the time sd-encrypt asks for the PIN.

**UKI layout.** `/etc/mkinitcpio.d/linux.preset` now declares `default_uki`
and `fallback_uki` at `/boot/EFI/Linux/arch-linux.efi` and
`/boot/EFI/Linux/arch-linux-fallback.efi`. systemd-boot auto-discovers both
and labels them correctly in the menu (if ever shown). The kernel cmdline
lives in `/etc/kernel/cmdline` — `rw quiet splash loglevel=3 rootflags=subvol=@
zswap.enabled=0 nvidia_drm.modeset=1 nvidia_drm.fbdev=1` — and is embedded
in each UKI at bake time. Legacy `/boot/loader/entries/*.conf` are archived
to `*.arche-bak` by `12-boot.sh` (not deleted — reversible).

**Why `nvidia_drm.modeset=1` and `nvidia_drm.fbdev=1` are explicit on the
cmdline even though `modinfo` reports both as module defaults.** First boot
after TPM2 enrollment the splash was black — user typed the PIN blind and
it worked. Journal showed `simpledrm` initializing fb0 at t=0, Plymouth
starting at t+1s, then `nvidia_drm` hotswapping fb0 at t+2s
(`fbcon: nvidia-drmdrmfb (fb0) is primary device`). Plymouth had already
opened `/dev/dri/card0` pointing at the now-unregistered simpledrm; its
framebuffer handle went stale and all subsequent draws went nowhere. The
password agent kept working — hence invisible-but-functional PIN entry.
The Arch linux kernel ships a patch that suppresses simpledrm registration
when it sees `nvidia_drm.modeset=1` parsed **from the cmdline specifically**;
the module's own default of `1` is checked too late (after simpledrm has
already bound). Being explicit on the cmdline short-circuits the handoff
entirely — simpledrm never binds, Plymouth opens the nvidia DRM device on
first try, splash is visible. `fbdev=1` gives plymouthd a persistent NVIDIA
fbdev to draw into (belt-and-braces; nvidia-open 580+ needs it for reliable
early-KMS splashes). Both flags are set in `system/etc/kernel/cmdline`;
`scripts/03-gpu.sh` guards against regression.

**TPM2 enrollment is a separate, explicit step.** `12-boot.sh` prepares the
boot chain but **does not** touch LUKS keyslots. The user runs
`just tpm-enroll` (→ `helpers/tpm2-enroll.sh`) when they're ready, and the
helper:
- Guards: refuses to run if there's no passphrase keyslot to fall back on
  (TPM-only is a lockout vector on any BIOS/bootloader update).
- Runs `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7
  --tpm2-with-pin=yes --wipe-slot=tpm2 <device>`.
- PCRs 0 and 7 seal against firmware measurement + Secure Boot state.
  Not PCR 4 (kernel + UKI) — that would re-seal on every kernel update.
  Acceptable trade-off: an attacker with physical access *and* the ability
  to swap the UKI in-place could bypass TPM, but they'd still need the PIN.
  For threat model = "stolen laptop", this is fine.
- Prints `luksDump` afterwards so the user can verify the enrollment.

**Rollback.** Revert the HOOKS change (remove
`/etc/mkinitcpio.conf.d/arche.conf` — the stock `/etc/mkinitcpio.conf`
still has `encrypt`), delete the UKIs, restore
`/boot/loader/entries/arch.conf.arche-bak` → `arch.conf`, rerun
`mkinitcpio -P` with the old preset. The TPM2 keyslot removal is
`sudo systemd-cryptenroll --wipe-slot=tpm2 <device>`. Passphrase keyslot is
never touched, so unlock continues to work throughout.

**Trade-offs / accepted costs:**
- UKI rebuild adds ~30s to kernel upgrades. The existing
  `95-boot-cleanup.hook` needs a minor tweak to also clean stale UKIs
  alongside kernels; noted as a follow-up.
- Any significant firmware update re-seals the TPM and invalidates the PCR
  policy → PIN stops working. Fallback passphrase is the recovery path.
  Re-run `just tpm-enroll` after firmware updates.
- Plymouth's `display_message_callback` fires once per error, not persistently
  — the script uses a one-tick `error_until` flag to hold the error state
  across one keystroke redraw. If Plymouth's behaviour changes upstream
  (unlikely — this API is stable) the error visual might need a rewrite.
- Cantarell is the Plymouth fallback font. If `Image.Text` doesn't pick up
  IBM Plex, the prompt line falls back to Cantarell at the same size. Visible
  but not broken.

---

## D023 — Hyprland restored, Quickshell panel replaces KDE + Waybar

**Date:** 2026-04-18
**Status:** Accepted (SDDM-theme clause amended by D025)
**Reverses:** D021 (KDE Plasma migration), D022 (plasma-login-manager swap)
**Obsoletes:** vendored SilentSDDM (the bespoke QML returns in D025, but as a ~450-line tree, not the old ~260-key plugin chain)

Hyprland is back as the desktop. Quickshell (arche-shell, an external QML-based
repo at <https://github.com/Dhruvpatel-10/quickshell>) is the single layer that
owns the bar, control-center, notifications, toasts, and OSD — all the pieces
that D021 handed to KDE Plasma's built-ins.

**What actually runs on this machine:**
- Compositor: `Hyprland` (wayland session) via `uwsm`
- Greeter: `sddm.service` (Breeze theme — no vendored theme)
- Panel: `quickshell -p ~/.config/quickshell/shell.qml` (spawns Bar-per-screen,
  ControlCenter, ToastLayer, NotificationsList)
- Launcher: `rofi-wayland`
- Lock / idle / night-light / wallpaper: `hyprlock` / `hypridle` / `hyprsunset` / `hyprpaper`
- Clipboard history: `cliphist` (wl-clipboard is already in base)
- Polkit: `hyprpolkitagent`
- Screen-share picker: `hyprland-preview-share-picker`

**Why:**
- Personal preference. After living with KDE for D021/D022 the user chose to
  come back to Hyprland — more control over the tiling and binding model,
  lower visual latency, tighter loop for keyboard-first workflows.
- Quickshell wasn't ready at D021 time; now it is. It collapses the old
  Waybar + Mako + SwayOSD + cliphist-menu split into one QML tree with a
  single theme source (`Theme.qml`) that lines up with `theming/themes/ember.sh`.
- Default Breeze SDDM theme is enough — the vendored SilentSDDM tree from
  D013 is not restored; it carried ~260 config keys of surface area and
  a QML import dependency chain that was never load-bearing. If the user
  wants a bespoke greeter later, vendor it at that point, not preemptively.

**What changed in the repo:**
- Scripts: `05-kde.sh` → `05-hyprland.sh`; new `07-panel.sh`; renumber
  `07-runtimes` → `08`, `08-apps` → `09`, `09-stow` → `10`, `10-appearance` → `11`.
- Packages: `kde.sh` → `hyprland.sh` (wm + wayland utils + rofi + sddm + Qt wayland bits).
  New `panel.sh` (quickshell + networkmanager). `apps.sh` swaps dolphin →
  nautilus, adds okular + gwenview (standalone, don't pull plasma).
  `appearance.sh` gains `nwg-look` (was handled by `kde-gtk-config` before).
- Stow: delete `stow/kde/`. Restore `stow/hypr/`, `stow/rofi/`, `stow/cliphist/`,
  `stow/hyprland-preview-share-picker/`. Merge the Hyprland-specific scripts
  that used to live under `stow/hypr/.local/bin/` into `stow/arche-scripts/` —
  keeps the D021 "compositor-agnostic location" refactor even though the
  scripts themselves are compositor-specific, because that's where they're
  already stowed on the live system and I don't want to churn the install
  tree a second time.
- Templates: restore `templates/hypr/`, `templates/rofi/`,
  `templates/hyprland-preview-share-picker/`. Delete `templates/kde/`.
  No waybar/mako/swayosd templates come back — Quickshell owns that layer and
  reads its own theme file.
- System: restore `system/etc/sddm.conf.d/10-arche.conf` (Breeze theme, X11
  greeter, IBM Plex Sans font).
- Desktop apps: remove dolphin, ffmpegthumbs from `apps.sh`. okular and
  gwenview stay (standalone — they pull in a few kde-frameworks packages but
  not plasma-desktop).

**The Quickshell source does NOT live inside arche.** `07-panel.sh` clones
Dhruvpatel-10/quickshell to `~/projects/system/arche-shell/` and symlinks
`~/.config/quickshell/` to that clone. This matches the pattern established by
the `tools/` convention (binaries built externally, pulled into the repo only
as prebuilt artefacts — see the "Tools" section of CLAUDE.md). Symlink-not-stow
because the shell is iterated on with hot-reload, and committing the QML into
arche would fight that loop.

**Deprecations:**
- D021 and D022 are reversed. The `stow/kde/`, `scripts/05-kde.sh`,
  `templates/kde/` trees are gone from the working tree (still in git history).
- `plasmalogin.service` is disabled by the new `05-hyprland.sh`; `sddm.service`
  takes over as the display-manager alias.
- The vendored `vendor/sddm-silent/` tree (D013) is not restored either —
  SilentSDDM was deprecated in D021 and stays that way. Default Breeze is
  sufficient, no theme vendoring.

**Trade-offs / accepted costs:**
- Reboot needed to switch greeter from plasmalogin → sddm.
- Reboot needed to switch session from Plasma → Hyprland (or log out and pick
  Hyprland at the greeter).
- arche-shell is a second repo to keep in sync — mitigated by `07-panel.sh`
  doing `git pull --ff-only` on each run so subsequent bootstraps stay current.
- Hyprland on the RTX 4060 laptop has more edge cases than Plasma (XWayland
  hiccups with some Electron apps, HDMI resume quirks — see `arche-hdmi-reset`).
  Accepted — the workflow win outweighs the friction for this user.

**Rollback:** `git revert` this commit range, re-enable `plasmalogin.service`,
disable `sddm.service`, restow `stow/kde/`. The D021/D022 trees are in git
history at commits `4c9e6d2` (D021) and `d5d7a34` (D022).

---

## D022 — plasma-login-manager replaces SDDM

**Date:** 2026-04-18
**Status:** Reversed (see D023 — SDDM restored)
**Amends:** D021 (SDDM was kept as login manager; now retired)
**Supersedes:** D013 (SilentSDDM theming — obsolete, theme system no longer applies)

Switched the display manager from SDDM to `plasma-login-manager`, the
KDE-native greeter introduced in Plasma 6.6. As of Arch's Plasma 6.6.4-1
package drop, `plasma-login-manager` is a member of the `plasma` group and a
direct dependency of `plasma-meta` — so on any fresh install of KDE on Arch,
it comes in automatically and provides the `display-manager.service` alias.
SDDM is no longer pulled in by the plasma group.

**What actually runs on this machine:**
- `plasmalogin.service` — active, enabled, aliased to `display-manager.service`
- `sddm.service` — was installed and enabled, now disabled and uninstalled

**Why:**
- KDE upstream's own replacement — written against the KDE frameworks, uses
  KWin for the greeter session instead of shipping a parallel Qt login stack.
  Smaller surface, fewer moving parts.
- Comes in with the plasma group by default — no explicit package to manage,
  one less thing to install at Arch-install time.
- Configuration is via a standard KCM (`systemsettings kcm_plasmalogin`),
  consistent with every other KDE config surface. No bespoke theme.conf or
  INI file tree like SDDM required.
- Removes the last reason `vendor/sddm-silent/` existed — the theming problem
  D013 was solving does not apply to plasma-login-manager.

**What we lose vs SDDM:**
- SDDM's theme ecosystem (breeze, maldives, maya, third-party QML themes) is
  not compatible. plasma-login-manager has a single look — Plasma's own
  greeter, styled by the active Plasma look-and-feel package. For arche this
  is fine; D021 had already committed to Breeze and dropped SilentSDDM.
- Configuration is KCM-driven (writes kconfig under the `sddm` system user's
  home via PAM/dbus helpers), not a drop-in `/etc/sddm.conf.d/*.conf`. We no
  longer ship a repo-owned config file for the login manager — defaults are
  correct, and any tweaks (user list, autologin) go through KCM.

**Files touched:**
- `scripts/05-kde.sh` — prereq check now asserts `plasma-login-manager`
  instead of `sddm`; `svc_enable plasmalogin` replaces `svc_enable sddm`;
  cleanup path added for `sddm.service`, stale SDDM themes, and the stale
  `/etc/sddm.conf.d/10-arche.conf` symlink.
- `packages/kde.sh` — header comment updated; still empty (plasma group
  provides plasma-login-manager).
- `system/etc/sddm.conf.d/10-arche.conf` — deleted. The enclosing
  `system/etc/sddm.conf.d/` directory is gone with it.
- `install.sh` — KDE prereq check asserts `plasma-login-manager` instead of
  `sddm`.
- `tests/test_gate.sh` — KDE prereq gate checks `plasma-login-manager`.
- `tests/test_integration.sh` — service-enabled check swaps `sddm` →
  `plasmalogin`.
- `helpers/migrate-to-opt.sh` — comment no longer calls out the `sddm` user
  specifically (the traversal rationale is the same for any system user).
- Docs — `CLAUDE.md`, `docs/architecture.md`, `docs/status.md`, `README.md`,
  `packages/CLAUDE.md` updated to reflect plasma-login-manager as the greeter.

**System-side cleanup (one-time, on already-installed machines):**
```
sudo systemctl disable --now sddm.service      # usually already disabled by Arch's upgrade
sudo systemctl enable --now plasmalogin.service
paru -Rns sddm sddm-kcm                        # sddm-kcm is the SDDM settings module, now orphaned
sudo rm -f /etc/sddm.conf.d/10-arche.conf
sudo rmdir /etc/sddm.conf.d 2>/dev/null || true
```
All of these are also idempotently handled by `scripts/05-kde.sh` on the next
bootstrap pass, except for the `paru -Rns` (package removal stays manual per
arche convention — see `packages/CLAUDE.md`).

**vendor/sddm-silent/ final status:** retained in git history only. Not
linked, not deployed, not referenced by any script. Safe to delete in a
future commit if disk hygiene matters.

---

## D021 — KDE Plasma replaces Hyprland as desktop environment

**Date:** 2026-04-16
**Status:** Reversed (see D023 — Hyprland restored, Quickshell replaces Plasma shell)
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

**SDDM:** Kept as login manager at the time of D021 — SDDM was the native
display manager for KDE Plasma. Switched from vendored SilentSDDM theme
(glassmorphism, see D013) to the Breeze theme that ships with KDE Plasma.
`vendor/sddm-silent/` is retained in git history but no longer deployed.
**Update (D022):** SDDM itself has since been retired in favour of
`plasma-login-manager`, the KDE-native greeter introduced in Plasma 6.6.
The `system/etc/sddm.conf.d/10-arche.conf` this decision referenced no
longer exists — see D022 for details.

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
- `packages/kde.sh` is intentionally empty — the `plasma` group is installed
  at Arch-install time (via archinstall or pacstrap), not by bootstrap.
  `scripts/05-kde.sh` verifies `plasma-desktop`, `kwin`, and (since D022)
  `plasma-login-manager` are present and fails fast if not.
- Hyprland compositor-agnostic leftovers also removed: `cliphist` (Klipper
  replaces it) and `brightnessctl` (Powerdevil handles brightness keys natively).
- `wl-clipboard` moved from `packages/kde.sh` to `packages/base.sh` — it's a
  general Wayland CLI, not KDE-specific.

**Script changes:**
- `scripts/05-hyprland.sh` renamed to `scripts/05-kde.sh`
- SilentSDDM theme installation removed; at the time of D021 SDDM was
  configured with Breeze. D022 later retired SDDM entirely in favour of
  `plasma-login-manager` — the SDDM-related lines in this script have since
  been rewritten accordingly.
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
**Status:** Reversed (see D026 — awww, swww's maintained successor, is the daemon)

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
values. Templating it from `theming/themes/ember.sh` would be high-effort and
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
- USBGuard — removed; see D030.

---

## D005 — Template vs stow: which layer owns what

**Date:** 2026-03-13
**Status:** Accepted

Decision rule: **does this config contain colors, fonts, or sizes?**

- **No** → stow package only (`stow/<name>/`). Symlinked as-is.
- **Yes** → behavior parts in stow, visual parts in `theming/templates/`. `theme.sh`
  renders the template to `~/.config/` (generated output, gitignored).
- **All visual, no behavior** → template only (e.g. mako).

Concrete mapping:

| Component  | stow/ (behavior)                 | theming/templates/ (visual)              |
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

Ember is the active theme (`theming/themes/ember.sh`). Warm amber (#c9943e) on deep
charcoal (#13151c). Originally started as Catppuccin Mocha, replaced with a
custom palette. All color values defined once in the theme file and consumed
via templates. Adding a new theme means creating a new shell file satisfying
`theming/themes/schema.sh`. See `docs/theme-standard.md` for the full specification.
