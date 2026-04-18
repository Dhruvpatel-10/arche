#!/usr/bin/env bash
# 12-boot.sh — Pre-boot UI (Plymouth) + UKI build + sd-encrypt switch
#
# This script touches the boot chain. It is idempotent but consequential:
#   · Switches mkinitcpio HOOKS from `encrypt` → `sd-encrypt`
#   · Writes a UKI-only linux.preset
#   · Installs a custom Plymouth theme (arche — subtle purple, ARCHE wordmark)
#   · Writes /etc/crypttab.initramfs with the real LUKS UUID (TPM2-ready but
#     not yet enrolled — enrollment is a separate, explicit step via
#     helpers/tpm2-enroll.sh / `just tpm-enroll`)
#   · Rebuilds the UKI with `mkinitcpio -P`
#
# After this script, a passphrase LUKS unlock still works (fallback keyslot
# untouched). TPM2+PIN becomes active only after the user runs the enrollment
# helper.
#
# Requires: ttf-ibm-plex (installed by 11-appearance.sh), imagemagick
# (installed by 09-apps.sh).

source "$(dirname "$0")/lib.sh"

log_info "Configuring pre-boot UI + UKI..."

# ─── Sanity: required deps from earlier scripts ─────────────────────────────
# Checked BEFORE package install so we fail fast without side-effects.

if ! pacman -Q imagemagick &>/dev/null; then
    log_err "imagemagick not installed — run 'just apps' (or 09-apps.sh) first"
    exit 1
fi
if ! pacman -Q ttf-ibm-plex &>/dev/null; then
    log_err "ttf-ibm-plex not installed — run 'just appearance' (or 11-appearance.sh) first"
    exit 1
fi

# ─── Symlink system configs FIRST ───────────────────────────────────────────
# Plymouth's pacman install trigger runs `mkinitcpio -P` as a hook. We need
# the HOOKS drop-in, linux.preset, kernel cmdline, AND /etc/crypttab.initramfs
# all in place before that, so the hook-triggered UKI build is already
# bootable — sd-encrypt can see the LUKS device, plymouth draws, cmdline
# has root=. Otherwise the first UKI is unbootable until the script's own
# final rebuild runs, which would brick boot if the user Ctrl+C'd mid-run.
link_system_all

# Rewrite /etc/crypttab.initramfs with the live LUKS UUID. tpm2-device=auto
# falls through to passphrase prompt until an actual TPM2 keyslot is enrolled
# (separate step, `just tpm-enroll`).
luks_part=$(lsblk -lnpo NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1; exit}')
if [[ -z "$luks_part" ]]; then
    log_err "No LUKS2 partition found — cannot configure sd-encrypt"
    exit 1
fi
luks_uuid=$(sudo blkid -s UUID -o value "$luks_part")
if [[ -z "$luks_uuid" ]]; then
    log_err "Failed to read LUKS UUID from $luks_part"
    exit 1
fi
crypttab_line="root UUID=${luks_uuid} - tpm2-device=auto"
log_info "Writing /etc/crypttab.initramfs: $crypttab_line"
echo "$crypttab_line" | sudo tee /etc/crypttab.initramfs >/dev/null
sudo chmod 600 /etc/crypttab.initramfs

install_group "$ARCHE/packages/boot.sh"

# Prefer the v7 `magick` CLI; fall back to legacy `convert`.
IM=magick
command -v magick &>/dev/null || IM=convert

# ─── 1. Deploy Plymouth theme ────────────────────────────────────────────────

theme_src="$ARCHE/tools/plymouth/arche"
theme_dst="/usr/share/plymouth/themes/arche"

log_info "Installing Plymouth theme 'arche' to $theme_dst..."
sudo install -d -m 755 "$theme_dst"
sudo install -m 644 "$theme_src/arche.plymouth" "$theme_dst/arche.plymouth"
sudo install -m 644 "$theme_src/arche.script"   "$theme_dst/arche.script"

# ─── 2. Render PNG assets ────────────────────────────────────────────────────
# Kept out of git — regenerated from the palette on every run. Cheap.

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Palette (match arche.script exactly).
FG_HEX="#c8bbdd"     # light lavender — wordmark
ACCENT_HEX="#a08dc4" # muted lavender — rule + dots
ERR_HEX="#b88a9a"    # dusty rose — error dots
BG_HEX="none"        # transparent; Window.SetBackground fills behind

# Wordmark: ARCHE in IBM Plex Sans Medium, letter-spaced, flat.
log_info "Rendering ARCHE wordmark..."
$IM -background "$BG_HEX" -fill "$FG_HEX" \
    -font "IBM-Plex-Sans-Medium" -pointsize 96 \
    -kerning 18 \
    label:"ARCHE" "$tmp/title.png"

# Hairline rule: 1×220 px @ 40% alpha.
log_info "Rendering accent rule..."
$IM -size 220x1 "xc:$ACCENT_HEX" -alpha set -channel A -evaluate multiply 0.4 +channel "$tmp/rule.png"

# PIN dots: 10×10 filled circle, accent and error colour.
log_info "Rendering PIN dots..."
$IM -size 10x10 xc:none -fill "$ACCENT_HEX" -draw "circle 5,5 5,0" "$tmp/dot.png"
$IM -size 10x10 xc:none -fill "$ERR_HEX"    -draw "circle 5,5 5,0" "$tmp/dot_error.png"

sudo install -m 644 "$tmp"/*.png "$theme_dst/"
log_ok "Theme assets rendered + installed"

# ─── 3. Set Plymouth default theme + link config ─────────────────────────────

sudo plymouth-set-default-theme arche
log_ok "Plymouth default theme = arche"

# ─── 4. Rebuild UKIs ────────────────────────────────────────────────────────
# Legacy loader entries are archived AFTER the UKI build succeeds — if
# mkinitcpio fails, systemd-boot still has a valid path to boot from the old
# entries on the next power-cycle.

log_info "Rebuilding UKIs (mkinitcpio -P) — this can take ~30s..."
sudo install -d -m 755 /boot/EFI/Linux
if sudo mkinitcpio -P; then
    log_ok "UKI rebuild complete"
else
    log_err "UKI rebuild failed — old loader entries untouched, safe to reboot on the current kernel."
    log_err "Fix the errors above, then re-run: just boot"
    exit 1
fi

# ─── 6. Verify UKI landed ───────────────────────────────────────────────────

if [[ ! -f /boot/EFI/Linux/arch-linux.efi ]]; then
    log_err "Default UKI missing — expected /boot/EFI/Linux/arch-linux.efi"
    log_err "Legacy loader entries untouched — safe to reboot."
    exit 1
fi
log_ok "Default UKI present at /boot/EFI/Linux/arch-linux.efi"

# ─── 7. Archive legacy systemd-boot loader entries ──────────────────────────
# Only after we've confirmed a working UKI exists. systemd-boot auto-discovers
# UKIs in /boot/EFI/Linux/ via BLS Type #2; the archived *.conf files aren't
# needed and would just create duplicate menu entries.

for entry in /boot/loader/entries/*.conf; do
    [[ -e "$entry" ]] || continue
    if grep -q "^linux\s*/vmlinuz" "$entry" 2>/dev/null; then
        log_info "Archiving legacy loader entry: $entry"
        sudo mv "$entry" "$entry.arche-bak"
    fi
done

log_ok "Pre-boot UI setup done"
log_info "Next step: enroll TPM2 + PIN via 'just tpm-enroll' (or helpers/tpm2-enroll.sh)"
log_info "Until then, the passphrase prompt still works (now rendered by Plymouth)."
