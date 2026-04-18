#!/usr/bin/env bash
# helpers/tpm2-enroll.sh — interactive TPM2 + PIN enrollment for the root LUKS
# volume.
#
# One-shot. Safe to re-run (systemd-cryptenroll replaces an existing TPM2
# keyslot instead of duplicating). Never strips the passphrase keyslot —
# TPM2 binds to PCRs 0+7 (firmware + SecureBoot state), and any firmware
# update re-seals the TPM, which will lock you out if you don't have a
# fallback. Keep the passphrase.
#
# Prerequisites: bash scripts/12-boot.sh has already run (Plymouth + sd-encrypt
# + UKI in place). This helper only touches the LUKS keyslots.
#
# Run as your normal user. The script uses sudo where needed.
set -euo pipefail

green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
cyan='\033[0;36m'
bold='\033[1m'
reset='\033[0m'

info()  { echo -e "${cyan}[INFO]${reset} $1"; }
ok()    { echo -e "${green}[✓]${reset} $1"; }
warn()  { echo -e "${yellow}[~]${reset} $1"; }
err()   { echo -e "${red}[✗]${reset} $1"; exit 1; }

[[ $EUID -eq 0 ]] && err "Run as your normal user, not root — script uses sudo."

# ─── Find the LUKS root device ──────────────────────────────────────────────

luks_part=$(lsblk -lnpo NAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1; exit}')
[[ -n "$luks_part" ]] || err "No LUKS2 partition found on this system."

info "Target LUKS device: ${bold}$luks_part${reset}"

# ─── Fallback passphrase keyslot check ──────────────────────────────────────
# Enrolling TPM2 without a passphrase fallback is a common footgun. Refuse if
# we can't see at least one `luks2` keyslot that isn't a TPM2 token.

keyslot_count=$(sudo cryptsetup luksDump "$luks_part" | awk '/^Keyslots:$/,/^Tokens:$/' | grep -c '^\s*[0-9]\+:' || true)
if (( keyslot_count < 1 )); then
    err "No LUKS keyslots detected on $luks_part — refusing to touch."
fi
ok "Found ${keyslot_count} existing keyslot(s) on $luks_part"

# Count TPM2 tokens separately — these don't count as fallback.
tpm2_token_count=$(sudo cryptsetup luksDump "$luks_part" | awk '/^Tokens:$/,EOF' | grep -c 'systemd-tpm2' || true)
passphrase_slots=$(( keyslot_count - tpm2_token_count ))

if (( passphrase_slots < 1 )); then
    err "No passphrase keyslot on $luks_part — refusing to enroll TPM2. Add a passphrase first: sudo cryptsetup luksAddKey $luks_part"
fi
ok "Passphrase keyslot present (${passphrase_slots}) — safe to enroll TPM2 alongside"

# ─── Confirm before touching ────────────────────────────────────────────────

echo
warn "This will enroll a TPM2+PIN keyslot on $luks_part."
warn "On the next boot, Plymouth will prompt for the PIN instead of the passphrase."
warn "The passphrase keyslot will NOT be removed — it stays as fallback."
echo
printf "  Continue? [y/N] "
read -r choice
[[ "$choice" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }

# ─── Enroll ──────────────────────────────────────────────────────────────────
# PCRs 0+7 = firmware + SecureBoot state. Safe default; rebind if you enable
# Secure Boot later or update firmware significantly.
# --wipe-slot=tpm2 replaces any existing TPM2 slot (idempotent re-run).

info "Running systemd-cryptenroll (will prompt for existing passphrase + new PIN)..."
sudo systemd-cryptenroll \
    --tpm2-device=auto \
    --tpm2-pcrs=0+7 \
    --tpm2-with-pin=yes \
    --wipe-slot=tpm2 \
    "$luks_part"

ok "TPM2 keyslot enrolled"

# ─── Verify ─────────────────────────────────────────────────────────────────

echo
info "LUKS keyslot summary after enrollment:"
sudo cryptsetup luksDump "$luks_part" | awk '/^Keyslots:$/,/^Digests:$/ { if(/^\s*[0-9]+:/||/^\s*Key:/||/^\s*Priority:/||/^Keyslots:$/) print "   " $0 }'
sudo cryptsetup luksDump "$luks_part" | awk '/^Tokens:$/,/^Digests:$/ { if(!/^Digests:$/) print "   " $0 }'
echo
ok "Enrollment complete. Reboot to test — passphrase fallback remains on another keyslot."
