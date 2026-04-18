#!/usr/bin/env bash
# 02-security.sh — firewall, SSH hardening, Tailscale, encrypted DNS, kernel hardening
#
# Each section is fully idempotent — safe to re-run, safe to ctrl+c.
# Interrupting between sections leaves everything configured so far intact.
#
# What this script configures:
#   Packages, Firewall (UFW), Tailscale, SSH hardening, Fail2ban,
#   Encrypted DNS, Kernel hardening, Lid close, MAC randomization,
#   USBGuard, Firejail, LUKS/TPM2 enrollment

source "$(dirname "$0")/lib.sh"

# link_system_file is provided by lib.sh

# ─────────────────────────────────────────────────────────────────────────────
# 1. Packages
# ─────────────────────────────────────────────────────────────────────────────

log_section "Security Packages"
log_info "Installing security tooling (ufw, openssh, tailscale, gnome-keyring, firejail)"
install_group "$ARCHE/packages/security.sh"

# ─────────────────────────────────────────────────────────────────────────────
# 2. Firewall — UFW with default deny
# ─────────────────────────────────────────────────────────────────────────────
# Policy: deny all incoming, allow all outgoing.
# Only two inbound exceptions:
#   - SSH (port 22)        — for remote access (key-only, hardened in step 4)
#   - tailscale0 interface — all Tailscale traffic is WireGuard-encrypted;
#     Syncthing, KDE Connect, and other services route through here
#     instead of exposing ports on the LAN.
#
# nftables is explicitly disabled — UFW is the sole firewall manager.
# Running both causes rule conflicts and silent drops.
# ─────────────────────────────────────────────────────────────────────────────

log_section "Firewall (UFW)"

# Disable nftables if active — prevents rule conflicts with UFW
if systemctl is-active --quiet nftables 2>/dev/null; then
    log_info "Stopping nftables (conflicts with UFW)..."
    sudo systemctl stop nftables
fi
if systemctl is-enabled --quiet nftables 2>/dev/null; then
    sudo systemctl disable nftables
    log_ok "nftables disabled — UFW is the sole firewall manager"
else
    log_warn "nftables already disabled"
fi

if command -v ufw &>/dev/null; then
    sudo ufw default deny incoming 2>/dev/null
    sudo ufw default allow outgoing 2>/dev/null
    log_info "Default policy: deny incoming, allow outgoing"

    # SSH only on Tailscale — not exposed on LAN or public interfaces.
    # All your devices are on the tailnet; no reason to listen elsewhere.
    sudo ufw delete allow ssh 2>/dev/null
    sudo ufw allow in on tailscale0 to any port 22 proto tcp 2>/dev/null
    log_info "Allowed: SSH only on tailscale0 (not LAN/public)"

    sudo ufw allow in on tailscale0 2>/dev/null
    log_info "Allowed: all traffic on tailscale0 (encrypted mesh)"

    svc_enable ufw
    log_ok "UFW active — deny incoming, SSH via tailscale only"
else
    log_err "ufw not found — firewall not configured"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Tailscale — encrypted mesh VPN
# ─────────────────────────────────────────────────────────────────────────────
# Tailscale provides a WireGuard mesh between your devices.
# Services like Syncthing and KDE Connect use this instead of LAN ports.
# After bootstrap, authenticate with: tailscale up
# ─────────────────────────────────────────────────────────────────────────────

log_section "Tailscale"
svc_enable tailscaled
log_info "Service running — authenticate after bootstrap: tailscale up"

# ─────────────────────────────────────────────────────────────────────────────
# 4. SSH Hardening
# ─────────────────────────────────────────────────────────────────────────────
# Drop-in config at /etc/ssh/sshd_config.d/99-hardened.conf:
#   - Password auth disabled (key-only)
#   - Root login disabled
#   - Pubkey auth enabled
# ─────────────────────────────────────────────────────────────────────────────

log_section "SSH Hardening"

local_sshd="/etc/ssh/sshd_config.d/99-hardened.conf"
if [[ ! -f "$local_sshd" ]]; then
    log_info "Writing hardened sshd config..."
    sudo mkdir -p /etc/ssh/sshd_config.d
    sudo tee "$local_sshd" > /dev/null <<'SSHD'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
SSHD
    svc_enable sshd
    log_ok "SSH hardened: key-only auth, no root login"
else
    log_warn "SSH hardening already in place: $local_sshd"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. Fail2ban — brute-force protection
# ─────────────────────────────────────────────────────────────────────────────
# Monitors auth logs and bans IPs after repeated failed logins.
# Default: 5 failures within 10 minutes → 1 hour ban.
# Uses systemd journal backend (no syslog dependency).
# ─────────────────────────────────────────────────────────────────────────────

log_section "Fail2ban (Brute-Force Protection)"

if command -v fail2ban-server &>/dev/null; then
    jail_local="/etc/fail2ban/jail.local"
    if [[ ! -f "$jail_local" ]]; then
        log_info "Configuring fail2ban sshd jail..."
        sudo tee "$jail_local" > /dev/null <<'F2B'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ssh
F2B
        log_ok "fail2ban configured: 5 failures / 10min → 1h ban"
    else
        log_warn "fail2ban jail.local already exists"
    fi
    svc_enable fail2ban
else
    log_err "fail2ban not found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. Encrypted DNS — NextDNS + Cloudflare fallback, DNS-over-TLS, DNSSEC
# ─────────────────────────────────────────────────────────────────────────────
# Primary:  NextDNS over TLS (port 853) — filtering + analytics
# Fallback: Cloudflare over TLS — kicks in if NextDNS is unreachable
# DNSSEC:   allow-downgrade — validates when available, doesn't break captive portals
# Config:   system/etc/systemd/resolved.conf (symlinked, not copied)
# ─────────────────────────────────────────────────────────────────────────────

log_section "Encrypted DNS (NextDNS + Cloudflare fallback)"

if [[ -z "${NEXTDNS_ID:-}" ]]; then
    log_err "NEXTDNS_ID not set — add it to secrets.sh (see secrets.sh.example)"
else
    # Render resolved.conf with actual NextDNS ID
    sed "s/NEXTDNS_ID/${NEXTDNS_ID}/g" "$ARCHE/system/etc/systemd/resolved.conf" \
        | sudo tee /etc/systemd/resolved.conf > /dev/null
    log_ok "Rendered resolved.conf with NextDNS ID"
fi

# Point /etc/resolv.conf to systemd-resolved stub
if [[ "$(readlink -f /etc/resolv.conf)" != "/run/systemd/resolve/stub-resolv.conf" ]]; then
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    log_ok "resolv.conf → systemd-resolved stub"
else
    log_warn "resolv.conf already using resolved stub"
fi

svc_enable systemd-resolved
log_info "Primary: NextDNS (DoT) → Fallback: Cloudflare (DoT) → DNSSEC validation on"

# ─────────────────────────────────────────────────────────────────────────────
# 7. Kernel Hardening — sysctl
# ─────────────────────────────────────────────────────────────────────────────
# Drop-in at /etc/sysctl.d/99-arche-hardening.conf. Applied at boot.
# Covers: SYN flood protection, spoofed packet filtering, ICMP hardening,
#         kernel pointer hiding, ptrace restriction, BPF hardening,
#         symlink/hardlink protection, core dump restriction.
# Zero performance cost — these are all boolean/policy switches.
# ─────────────────────────────────────────────────────────────────────────────

log_section "Kernel Hardening (sysctl)"

link_system_file "$ARCHE/system/etc/sysctl.d/99-arche-hardening.conf" \
    "/etc/sysctl.d/99-arche-hardening.conf"

# Apply immediately without waiting for reboot
if sudo sysctl --system &>/dev/null; then
    log_ok "Sysctl rules applied (SYN cookies, rp_filter, ptrace restrict, BPF harden)"
else
    log_warn "Sysctl rules linked — will apply on next boot"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 8. Lid Close — explicit logind behavior
# ─────────────────────────────────────────────────────────────────────────────
# Makes lid close behavior explicit instead of relying on logind defaults.
# Hypridle locks the screen before sleep (via loginctl lock-session),
# so the chain is: lid close → logind suspends → hypridle locks first.
# Docked with external display: lid close is ignored.
# ─────────────────────────────────────────────────────────────────────────────

log_section "Lid Close Behavior (logind)"

link_system_file "$ARCHE/system/etc/systemd/logind.conf.d/99-arche.conf" \
    "/etc/systemd/logind.conf.d/99-arche.conf"

log_info "Lid close → suspend (on battery and AC). Docked → ignored."
log_info "Hypridle locks screen before sleep via loginctl lock-session"

# ─────────────────────────────────────────────────────────────────────────────
# 9. MAC Address Randomization — WiFi privacy
# ─────────────────────────────────────────────────────────────────────────────
# Randomizes the WiFi MAC address per-network, so your hardware ID
# isn't broadcast to every network you scan or connect to.
# Detects NetworkManager or iwd at runtime and configures whichever is present.
# ─────────────────────────────────────────────────────────────────────────────

log_section "MAC Address Randomization"

if command -v nmcli &>/dev/null; then
    nm_conf="/etc/NetworkManager/conf.d/99-mac-randomize.conf"
    if [[ ! -f "$nm_conf" ]]; then
        sudo mkdir -p /etc/NetworkManager/conf.d
        sudo tee "$nm_conf" > /dev/null <<'NM'
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
NM
        log_ok "NetworkManager: MAC randomized for WiFi scan + connect"
        log_info "Restart NetworkManager to apply: sudo systemctl restart NetworkManager"
    else
        log_warn "NetworkManager MAC randomization already configured"
    fi
elif [[ -d /etc/iwd ]] || command -v iwctl &>/dev/null; then
    iwd_conf="/etc/iwd/main.conf"
    if ! grep -q "AddressRandomization" "$iwd_conf" 2>/dev/null; then
        sudo mkdir -p /etc/iwd
        # Append if file exists, create if not
        if [[ -f "$iwd_conf" ]]; then
            if ! grep -q "\\[General\\]" "$iwd_conf"; then
                printf '\n[General]\n' | sudo tee -a "$iwd_conf" > /dev/null
            fi
            sudo sed -i '/\[General\]/a AddressRandomization=network' "$iwd_conf"
        else
            sudo tee "$iwd_conf" > /dev/null <<'IWD'
[General]
AddressRandomization=network
IWD
        fi
        log_ok "iwd: MAC randomized per-network"
    else
        log_warn "iwd MAC randomization already configured"
    fi
else
    log_warn "No NetworkManager or iwd detected — skipping MAC randomization"
    log_info "If you add a network manager later, re-run this script"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 10. USBGuard — block unknown USB devices
# ─────────────────────────────────────────────────────────────────────────────
# All currently connected USB devices are allowed (policy generated from
# current state). Any NEW device plugged in after this is blocked by default.
# Use `usb-inspect` to safely examine blocked devices in a sandbox.
#
# Flow: plug in unknown USB → USBGuard blocks it → `usb-inspect` →
#       mount read-only in firejail sandbox → inspect → allow or keep blocked.
# ─────────────────────────────────────────────────────────────────────────────

log_section "USBGuard (USB Device Control)"

if command -v usbguard &>/dev/null; then
    rules_file="/etc/usbguard/rules.conf"

    # Generate initial policy from currently connected devices (one-time)
    if [[ ! -f "$rules_file" ]] || [[ ! -s "$rules_file" ]]; then
        log_info "Generating USB policy from currently connected devices..."
        sudo mkdir -p /etc/usbguard
        sudo usbguard generate-policy | sudo tee "$rules_file" > /dev/null
        log_ok "Policy generated — all current USB devices are allowed"
        log_info "Any NEW device plugged in after this will be blocked"
    else
        log_warn "USB policy already exists: $rules_file"
    fi

    svc_enable usbguard
    log_ok "USBGuard active — unknown USB devices are blocked"
    log_info "Inspect blocked devices: usb-inspect"
    log_info "List blocked devices:    usb-inspect list"
    log_info "Allow permanently:       usb-inspect allow <id>"
else
    log_err "usbguard not found — USB device control not configured"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 11. Firejail — app sandboxing
# ─────────────────────────────────────────────────────────────────────────────
# Firejail sandboxes individual apps: restricts filesystem, network, syscalls.
# Has 1000+ built-in profiles for common apps.
#
# Usage:
#   firejail <app>              — run any app sandboxed with its default profile
#   firejail --appimage app.ai  — sandbox an AppImage
#   firejail --net=none <app>   — sandbox with no network
#   firejail --list             — show currently sandboxed processes
#   sudo firecfg                — auto-sandbox all apps with profiles (optional)
#
# NOT auto-enabled globally — use explicitly or run `firecfg` yourself.
# This avoids breaking apps that need unrestricted access (IDEs, terminals).
# ─────────────────────────────────────────────────────────────────────────────

log_section "Firejail (App Sandboxing)"

if command -v firejail &>/dev/null; then
    # Count available profiles
    profile_count=$(find /etc/firejail -name '*.profile' 2>/dev/null | wc -l)
    log_ok "Firejail installed — $profile_count app profiles available"

    echo ""
    log_info "Quick reference:"
    log_info "  Sandbox any app:     firejail <app>"
    log_info "  Sandbox an AppImage: firejail --appimage ./app.AppImage"
    log_info "  No network:          firejail --net=none <app>"
    log_info "  Private home:        firejail --private <app>"
    log_info "  List sandboxed:      firejail --list"
    echo ""
    log_info "Auto-sandbox all apps with profiles (optional, review first):"
    log_info "  Preview: firecfg --list"
    log_info "  Apply:   sudo firecfg"
    log_info "  Revert:  sudo firecfg --clean"
else
    log_err "firejail not found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 12. Post-Setup Guidance
# ─────────────────────────────────────────────────────────────────────────────

log_section "Post-Setup — Manual Steps"

log_info "Tailscale: run 'tailscale up' to authenticate this device"
log_info "SSH keys:  copy your ed25519 pubkey to this machine if needed"

# ─── LUKS + TPM2 + PIN enrollment ───
# If LUKS partitions exist and TPM2 is available, offer to enroll.
# TPM2 binds the disk to THIS hardware — password-free boot on this machine,
# encrypted if the drive is removed. PIN adds 6-digit theft protection
# (hardware rate-limited to ~32 attempts before lockout).

echo ""
luks_parts=$(lsblk -nro NAME,FSTYPE | awk '$2 == "crypto_LUKS" {print "/dev/" $1}')

if [[ -z "$luks_parts" ]]; then
    log_warn "No LUKS partitions detected — skipping TPM2 enrollment"
    log_info "Set up LUKS during Arch install for disk encryption"
elif ! command -v systemd-cryptenroll &>/dev/null; then
    log_warn "systemd-cryptenroll not found — skipping TPM2 enrollment"
elif [[ ! -d /sys/class/tpm/tpm0 ]]; then
    log_warn "No TPM2 chip detected — skipping hardware enrollment"
    log_info "Your LUKS partitions: $luks_parts"
else
    log_info "LUKS partitions found: $luks_parts"
    log_info "TPM2 chip detected"
    echo ""
    log_info "TPM2 + PIN enrollment binds disk encryption to this hardware."
    log_info "  - Boot on this machine: enter 6-digit PIN (no full passphrase)"
    log_info "  - Drive removed/stolen: stays fully encrypted"
    log_info "  - PIN is hardware rate-limited (~32 tries → lockout)"
    echo ""

    for part in $luks_parts; do
        # Check if TPM2 is already enrolled
        if systemd-cryptenroll "$part" --tpm2-device=list 2>/dev/null | grep -q 'tpm2'; then
            log_warn "TPM2 already enrolled on $part"
            continue
        fi

        printf "  Enroll TPM2 + PIN on %s? [y/N] " "$part"
        read -r choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
            log_info "Enrolling TPM2 + PIN on $part..."
            log_info "You'll be asked for your LUKS passphrase, then a new 6-digit PIN."
            if sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes "$part"; then
                log_ok "TPM2 + PIN enrolled on $part"
            else
                log_err "Enrollment failed on $part — your existing passphrase still works"
            fi
        else
            log_warn "Skipped TPM2 enrollment for $part"
        fi
    done
fi

echo ""
log_ok "Security setup complete"
