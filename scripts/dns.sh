#!/usr/bin/env bash
# scripts/dns.sh — deploy /etc/systemd/resolved.conf and restart
# systemd-resolved.
#
# Two modes, picked by whether NEXTDNS_ID (from secrets.sh) is set:
#
#   1. Full — NextDNS (DoT) primary → Cloudflare (DoT) → Google (DoT)
#      fallback. Renders system/etc/systemd/resolved.conf with the ID
#      substituted.
#
#   2. Degraded — Cloudflare (DoT) primary + Google (DoT) fallback,
#      inlined via heredoc. Emitted when secrets.sh is missing or the
#      ID isn't set, so a fresh clone without secrets still gets
#      encrypted DNS. Re-run `just dns` after adding NEXTDNS_ID to
#      promote NextDNS back to primary.
#
# Runnable standalone (called by `just dns`) and from
# scripts/02-security.sh during bootstrap. Idempotent in both modes.

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

# link_system_all (preflight) creates a symlink at /etc/systemd/resolved.conf
# back into the repo template. We render through a real file instead so
# the NextDNS ID never lands in the tree; unlink first so `sudo tee`
# doesn't write the rendered content back through the symlink.
if [[ -L /etc/systemd/resolved.conf ]]; then
    sudo rm /etc/systemd/resolved.conf
fi

if [[ -z "${NEXTDNS_ID:-}" ]]; then
    log_section "Encrypted DNS — DEGRADED (Cloudflare + Google DoT, no NextDNS)"
    log_warn "NEXTDNS_ID not set — deploying Cloudflare primary + Google fallback."
    log_warn "Add NEXTDNS_ID to secrets.sh (see secrets.sh.example) and re-run:"
    log_warn "    just dns"
    sudo tee /etc/systemd/resolved.conf > /dev/null <<'EOF'
# /etc/systemd/resolved.conf — managed by arche (DEGRADED: no NEXTDNS_ID)
# Cloudflare (DoT) primary + Google (DoT) fallback. `just dns` redeploys
# with NextDNS as primary once NEXTDNS_ID is set in secrets.sh.

[Resolve]
DNS=1.1.1.1#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one
FallbackDNS=8.8.8.8#dns.google
FallbackDNS=8.8.4.4#dns.google
FallbackDNS=2001:4860:4860::8888#dns.google
FallbackDNS=2001:4860:4860::8844#dns.google
DNSOverTLS=yes
DNSSEC=allow-downgrade
EOF
else
    log_section "Encrypted DNS — NextDNS (DoT) + Cloudflare + Google fallback"
    sed "s/NEXTDNS_ID/${NEXTDNS_ID}/g" "$ARCHE/system/etc/systemd/resolved.conf" \
        | sudo tee /etc/systemd/resolved.conf > /dev/null
fi

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
