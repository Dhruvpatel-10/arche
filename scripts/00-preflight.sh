#!/usr/bin/env bash
# 00-preflight.sh — sanity checks, system config, pacman, mirrors, update
source "$(dirname "$0")/lib.sh"

log_info "Running preflight checks..."

# ─── Sanity Checks ───

# Must be Arch Linux
if [[ ! -f /etc/arch-release ]]; then
    log_err "Not Arch Linux — aborting"
    exit 1
fi
log_ok "Arch Linux detected"

# Must have sudo
if ! command -v sudo &>/dev/null; then
    log_err "sudo not found — install it first"
    exit 1
fi
log_ok "sudo available"

# Must have internet
if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
    log_err "No internet — check connection"
    exit 1
fi
log_ok "Internet reachable"

# ─── Link System Configs ───
# Auto-discover and symlink everything under system/ to /
# Adding a new file to system/etc/foo automatically gets linked here.
link_system_all
svc_enable snapper-cleanup.timer

# ─── Disable btrfs qgroups on snapshotted subvolumes ───
# snapper create-config silently enables btrfs quota at FS level, even when
# the snapper config sets QGROUP="". Once on, btrfs-cleaner has to recompute
# qgroup accounting for every freed extent during snapshot cleanup, which
# causes multi-second IO stalls and load spikes (especially at boot when
# btrfs replays pending subvolume deletions). We never use qgroup-aware
# cleanup, so disable quotas entirely. Idempotent: btrfs quota disable is
# a no-op when already off.
for _mp in / /home; do
    if sudo btrfs qgroup show "$_mp" &>/dev/null; then
        log_info "Disabling btrfs qgroups on $_mp..."
        if sudo btrfs quota disable "$_mp"; then
            log_ok "qgroups disabled on $_mp"
        else
            log_warn "btrfs quota disable failed on $_mp"
        fi
    else
        log_warn "qgroups already off on $_mp"
    fi
done

# ─── Disable snapper-timeline.timer ───
# Both root and home configs have TIMELINE_CREATE="no". The timer just runs
# cleanup on a snapshot list that's always empty — pure waste. snapper-cleanup
# (number-based) is the only timer we need.
if systemctl is-enabled snapper-timeline.timer &>/dev/null; then
    log_info "Disabling snapper-timeline.timer (timeline snapshots are off)..."
    sudo systemctl disable --now snapper-timeline.timer
    log_ok "snapper-timeline.timer disabled"
else
    log_warn "snapper-timeline.timer already disabled"
fi

# ─── Mirror Ranking ───

if ! command -v reflector &>/dev/null; then
    log_info "Installing reflector for mirror ranking..."
    pkg_install reflector
fi

if command -v reflector &>/dev/null; then
    mirrorlist="/etc/pacman.d/mirrorlist"
    # Only re-rank if mirrorlist is older than 24 hours or missing
    if [[ ! -f "$mirrorlist" ]] || \
       [[ "$(find "$mirrorlist" -mmin +1440 2>/dev/null)" ]]; then
        log_info "Ranking mirrors (this may take a moment)..."
        sudo reflector \
            --protocol https \
            --age 12 \
            --sort rate \
            --number 20 \
            --save "$mirrorlist"
        log_ok "Mirrors ranked — top 20 HTTPS mirrors"
    else
        log_warn "Mirrorlist is fresh (< 24h) — skipping reflector"
    fi

    # Enable reflector timer for ongoing updates
    svc_enable reflector.timer
fi

# ─── Full System Update ───

log_info "Running full system update..."
sudo pacman -Syu

# ─── Reboot Gate ───
# If pacman -Syu upgraded the kernel, /usr/lib/modules/$(uname -r) is gone
# (pacman removed the old kernel's modules). Running further scripts on a
# stale kernel is bad — especially 03-gpu-nvidia which builds DKMS modules
# against the current headers. Signal bootstrap.sh to prompt for reboot.
if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
    log_warn "Kernel was upgraded — running kernel $(uname -r) has no modules installed"
    log_info "Bootstrap must pause here. Reboot, then re-run: bash bootstrap.sh"
    exit 2
fi

# ─── AUR Helper Check ───

if ! command -v paru &>/dev/null; then
    log_info "Installing paru (AUR helper)..."
    pkg_install base-devel
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    (cd /tmp/paru && makepkg -si)
    rm -rf /tmp/paru
    if command -v paru &>/dev/null; then
        log_ok "paru installed"
    else
        log_err "paru installation failed — AUR packages will be skipped"
    fi
fi

log_ok "Preflight complete"
