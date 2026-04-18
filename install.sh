#!/usr/bin/env bash
# install.sh — one-liner bootstrap for arche
# Usage: curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh | bash
#
# Prerequisite: Arch Linux (base install is enough). arche installs Hyprland,
# SDDM, and the Wayland utility stack itself — no desktop need be preinstalled.
# See D023.
#
# Clones the repo to /opt/arche so multiple human users on the same machine
# share one source of truth (see docs/decisions.md D014). Creates a per-user
# ~/arche → /opt/arche compat symlink so older scripts and shortcuts still
# work transparently.
set -euo pipefail

ARCHE_REPO="https://github.com/Dhruvpatel-10/arche.git"
ARCHE_DIR="/opt/arche"
SHARED_GROUP="users"
HOME_LINK="$HOME/arche"

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
    sudo -u "$USER" git -C "$ARCHE_DIR" pull --ff-only || err "Pull failed — resolve manually"
    ok "Updated"
else
    if [[ -e "$ARCHE_DIR" ]]; then
        err "$ARCHE_DIR exists but is not a git repo — remove it first or clone manually"
    fi
    info "Creating $ARCHE_DIR (needs sudo for /opt)..."
    sudo install -d -m 2775 -o "$USER" -g "$SHARED_GROUP" "$ARCHE_DIR"
    info "Cloning arche to $ARCHE_DIR..."
    git clone "$ARCHE_REPO" "$ARCHE_DIR"
    ok "Cloned"
fi

# ─── Permissions (idempotent) ───

# Make sure both the current user and any future user in the `users` group
# can read and write the tree, and that new files inherit the shared group.
sudo chown -R "$USER:$SHARED_GROUP" "$ARCHE_DIR"
sudo find "$ARCHE_DIR" -type d -exec chmod 2775 {} \;
ok "Permissions set ($USER:$SHARED_GROUP, setgid dirs)"

# ─── Compat symlink ───

if [[ -L "$HOME_LINK" ]]; then
    :  # already linked
elif [[ -e "$HOME_LINK" ]]; then
    err "$HOME_LINK exists and is not a symlink — refusing to overwrite"
else
    ln -s "$ARCHE_DIR" "$HOME_LINK"
    ok "Symlinked $HOME_LINK → $ARCHE_DIR"
fi

# ─── Bootstrap ───

info "Starting bootstrap..."
exec bash "$ARCHE_DIR/bootstrap.sh"
