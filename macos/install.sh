#!/usr/bin/env bash
# macos/install.sh — one-liner bootstrap for arche on macOS (Apple Silicon).
#
# Usage (preserves the terminal for sudo / brew prompts):
#   bash <(curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/macos/install.sh)
#
# Clones the repo to ~/arche (override with ARCHE_DIR=/path) and runs the
# macOS bootstrap. The clone is PERMANENT: stow symlinks (~/.config/*) point
# back into it, so don't delete or move it afterward.
#
# Unlike the Linux install.sh there's no /opt/arche or shared `users` group —
# a Mac is single-user, so the repo just lives in your home directory.
set -euo pipefail

ARCHE_REPO="${ARCHE_REPO:-https://github.com/Dhruvpatel-10/arche.git}"
ARCHE_DIR="${ARCHE_DIR:-$HOME/arche}"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m[✗]\033[0m %s\n' "$1"; exit 1; }

# ─── Checks ───

[[ "$(uname -s)" == "Darwin" ]] || err "Not macOS — on Arch use the top-level install.sh"
[[ "$(uname -m)" == "arm64"  ]] || err "Apple Silicon (arm64) only"
command -v git &>/dev/null || err "git not found — run: xcode-select --install"

# ─── Clone or update ───

if [[ -d "$ARCHE_DIR/.git" ]]; then
    info "arche already at $ARCHE_DIR — pulling latest..."
    git -C "$ARCHE_DIR" pull --ff-only || err "Pull failed — resolve manually"
    ok "Updated"
elif [[ -e "$ARCHE_DIR" ]]; then
    err "$ARCHE_DIR exists but is not a git repo — remove it or set ARCHE_DIR=/path"
else
    info "Cloning arche to $ARCHE_DIR..."
    git clone "$ARCHE_REPO" "$ARCHE_DIR"
    ok "Cloned"
fi

# ─── Bootstrap ───

info "Starting macOS bootstrap..."
exec bash "$ARCHE_DIR/macos/bootstrap.sh"
