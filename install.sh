#!/usr/bin/env bash
# install.sh — one-liner bootstrap for arche
# Usage: curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh | bash
set -euo pipefail

ARCHE_REPO="https://github.com/Dhruvpatel-10/arche.git"
ARCHE_DIR="$HOME/arche"

# ─── Helpers ───

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[✓]\033[0m %s\n' "$1"; }
err()   { printf '\033[1;31m[✗]\033[0m %s\n' "$1"; exit 1; }

# ─── Checks ───

[[ -f /etc/arch-release ]] || err "Not Arch Linux — aborting"
command -v git &>/dev/null  || err "git not found — install with: pacman -S git"
command -v sudo &>/dev/null || err "sudo not found"
ping -c 1 -W 3 archlinux.org &>/dev/null || err "No internet"

# ─── Clone or Update ───

if [[ -d "$ARCHE_DIR/.git" ]]; then
    info "arche already exists at $ARCHE_DIR — pulling latest..."
    git -C "$ARCHE_DIR" pull --ff-only || err "Pull failed — resolve manually"
    ok "Updated"
else
    if [[ -d "$ARCHE_DIR" ]]; then
        err "$ARCHE_DIR exists but is not a git repo — remove it first or clone manually"
    fi
    info "Cloning arche to $ARCHE_DIR..."
    git clone "$ARCHE_REPO" "$ARCHE_DIR"
    ok "Cloned"
fi

# ─── Bootstrap ───

info "Starting bootstrap..."
exec bash "$ARCHE_DIR/bootstrap.sh"
