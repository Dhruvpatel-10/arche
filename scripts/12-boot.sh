#!/usr/bin/env bash
# 12-boot.sh — UKI build + sd-encrypt switch
#
# This script touches the boot chain. It is idempotent but consequential:
#   · Switches mkinitcpio HOOKS from `encrypt` → `sd-encrypt` (via the
#     /etc/mkinitcpio.conf.d/arche.conf drop-in)
#   · Writes a UKI-only linux.preset
#   · Writes /etc/crypttab.initramfs with the real LUKS UUID (TPM2-ready but
#     not yet enrolled — enrollment is a separate, explicit step via
#     helpers/tpm2-enroll.sh / `just tpm-enroll`)
#   · Rebuilds the UKI with `mkinitcpio -P`
#
# After this script, a passphrase LUKS unlock still works (fallback keyslot
# untouched). TPM2+PIN becomes active only after the user runs the enrollment
# helper. The passphrase / PIN prompt appears on the plain kernel TTY — no
# graphical splash.

source "$(dirname "$0")/lib.sh"

log_info "Configuring sd-encrypt + UKI..."

# ─── Symlink system configs FIRST ───────────────────────────────────────────
# HOOKS drop-in, linux.preset, kernel cmdline, AND /etc/crypttab.initramfs all
# need to be in place before any pacman-triggered `mkinitcpio -P` runs, so the
# hook-built UKI is already bootable — sd-encrypt can see the LUKS device,
# cmdline has root=. Otherwise the first UKI is unbootable until the script's
# own final rebuild runs, which would brick boot if the user Ctrl+C'd mid-run.
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

# ─── Rebuild UKIs ──────────────────────────────────────────────────────────
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

# ─── Verify UKI landed ─────────────────────────────────────────────────────

if [[ ! -f /boot/EFI/Linux/arch-linux.efi ]]; then
    log_err "Default UKI missing — expected /boot/EFI/Linux/arch-linux.efi"
    log_err "Legacy loader entries untouched — safe to reboot."
    exit 1
fi
log_ok "Default UKI present at /boot/EFI/Linux/arch-linux.efi"

# ─── Archive legacy systemd-boot loader entries ────────────────────────────
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

log_ok "Boot setup done"
log_info "Next step: enroll TPM2 + PIN via 'just tpm-enroll' (or helpers/tpm2-enroll.sh)"
log_info "Until then, the passphrase prompt still works (plain TTY, no splash)."
