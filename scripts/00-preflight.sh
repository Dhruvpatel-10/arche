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
# Before stow is installed, we use ln for /etc/ and /usr/local/bin/ files.
# link_system_file is provided by lib.sh

# Pacman config
link_system_file "$ARCHE/system/etc/pacman.conf" "/etc/pacman.conf"

# Pacman hooks
for hook in "$ARCHE/system/etc/pacman.d/hooks/"*.hook; do
    [[ -f "$hook" ]] || continue
    link_system_file "$hook" "/etc/pacman.d/hooks/$(basename "$hook")"
done

# System scripts
for script in "$ARCHE/system/usr/local/bin/"*; do
    [[ -f "$script" ]] || continue
    link_system_file "$script" "/usr/local/bin/$(basename "$script")"
    sudo chmod +x "/usr/local/bin/$(basename "$script")"
done

# Snapper config (btrfs snapshot limits — must exist before pacman hooks fire)
link_system_file "$ARCHE/system/etc/snapper/configs/root" "/etc/snapper/configs/root"

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
