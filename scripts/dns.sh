#!/usr/bin/env bash
# scripts/dns.sh — render /etc/systemd/resolved.conf from the template
# at system/etc/systemd/resolved.conf, substituting NEXTDNS_ID from
# secrets.sh, then restart systemd-resolved.
#
# Runnable standalone (called by `just dns` for re-runs) and from
# scripts/02-security.sh during bootstrap. Idempotent: re-running just
# re-renders + restarts, which is exactly what we want when the
# NextDNS profile changes or the template is edited.

set -euo pipefail

ARCHE="${ARCHE:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=scripts/lib.sh
source "$ARCHE/scripts/lib.sh"

# Load NEXTDNS_ID from secrets.sh (gitignored). secrets.sh.example
# documents the expected shape.
if [[ -f "$ARCHE/secrets.sh" ]]; then
    # shellcheck disable=SC1091
    source "$ARCHE/secrets.sh"
fi

if [[ -z "${NEXTDNS_ID:-}" ]]; then
    log_err "NEXTDNS_ID not set — create secrets.sh from secrets.sh.example"
    exit 1
fi

log_section "Encrypted DNS — NextDNS (DoT) + Cloudflare + Google fallback"

# link_system_all (preflight) creates a symlink at /etc/systemd/resolved.conf
# back into the repo template. We render through a real file instead so
# the NextDNS ID never lands in the tree; unlink first so `sudo tee`
# doesn't write the rendered content back through the symlink.
if [[ -L /etc/systemd/resolved.conf ]]; then
    sudo rm /etc/systemd/resolved.conf
fi

sed "s/NEXTDNS_ID/${NEXTDNS_ID}/g" "$ARCHE/system/etc/systemd/resolved.conf" \
    | sudo tee /etc/systemd/resolved.conf > /dev/null
sudo chmod 644 /etc/systemd/resolved.conf
log_ok "Rendered /etc/systemd/resolved.conf"

if [[ "$(readlink -f /etc/resolv.conf)" != "/run/systemd/resolve/stub-resolv.conf" ]]; then
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    log_ok "resolv.conf → systemd-resolved stub"
fi

sudo systemctl restart systemd-resolved
sudo resolvectl flush-caches
log_ok "systemd-resolved restarted + caches flushed"

# Quick visibility check — first few lines of resolvectl status tell
# us whether the stub picked up the new config.
resolvectl status | sed -n '1,12p'
