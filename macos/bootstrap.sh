#!/usr/bin/env bash
# macos/bootstrap.sh — clean, minimal macOS setup for arche.
#
# A short cross-platform slice of the Arch bootstrap: installs the shared
# CLI + terminal tooling via Homebrew, symlinks the portable stow packages,
# sets fish as the login shell, and renders the active theme through the
# SAME engine the Linux path uses (theming/engine.sh). No window manager,
# no system services — just the "normal apps" (fish, nvim, ghostty, tmux …).
#
# Run: bash macos/bootstrap.sh
set -euo pipefail

MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHE="$(cd "$MACOS_DIR/.." && pwd)"
export ARCHE

# lib.sh gives us stow_pkg + log_* (pacman helpers go unused here).
source "$ARCHE/scripts/lib.sh"

# ─── Guard: macOS only ───

if [[ "$(uname -s)" != "Darwin" ]]; then
    log_err "This is the macOS bootstrap — on Linux run: bash bootstrap.sh"
    exit 1
fi

# Apple Silicon only — Homebrew lives at /opt/homebrew, casks are arm64.
if [[ "$(uname -m)" != "arm64" ]]; then
    log_err "This setup targets Apple Silicon (arm64) only — Intel Macs are not supported"
    exit 1
fi

log_info "=== arche macOS bootstrap ==="
log_info "ARCHE=$ARCHE"
echo

# ─── 1. Homebrew ───

# On a fresh machine brew is installed but not yet on PATH (the user hasn't
# opened a new shell). Resolve it from the Apple Silicon prefix.
if ! command -v brew &>/dev/null && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew &>/dev/null; then
    log_err "Homebrew not found. Install it first, then re-run this script:"
    log_info '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Install per-package (reading the Brewfile as the source of truth) instead of
# one opaque `brew bundle` call — that downloads every bottle silently up front
# and looks frozen for minutes. This shows clean [n/total] progress and skips
# anything already installed. (macOS ships bash 3.2 — no mapfile/readarray, so
# we collect with a plain read loop.)
BREWFILE="$MACOS_DIR/Brewfile"

# Don't re-check the whole tap on every install; we accept slightly staler
# formulae in exchange for fast, quiet, predictable output.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

formulae=()
while IFS= read -r name; do formulae+=("$name"); done \
    < <(sed -nE 's/^[[:space:]]*brew "([^"]+)".*/\1/p' "$BREWFILE")
casks=()
while IFS= read -r name; do casks+=("$name"); done \
    < <(sed -nE 's/^[[:space:]]*cask "([^"]+)".*/\1/p' "$BREWFILE")

total=$(( ${#formulae[@]} + ${#casks[@]} ))
n=0
failed=()
log_info "Installing $total Homebrew packages (${#formulae[@]} formulae, ${#casks[@]} casks)..."
echo

for f in "${formulae[@]}"; do
    n=$(( n + 1 ))
    if brew list --formula --versions "$f" &>/dev/null; then
        log_warn "[$n/$total] $f — already installed"
    else
        log_info "[$n/$total] Installing ${f}..."
        brew install --formula "$f" || failed+=("$f")
    fi
done

for c in "${casks[@]}"; do
    n=$(( n + 1 ))
    if brew list --cask --versions "$c" &>/dev/null; then
        log_warn "[$n/$total] $c — already installed"
    else
        log_info "[$n/$total] Installing cask ${c}..."
        brew install --cask "$c" || failed+=("$c")
    fi
done

echo
if [[ ${#failed[@]} -gt 0 ]]; then
    log_warn "Failed to install: ${failed[*]}"
    log_warn "Re-run the bootstrap to retry — installed packages are skipped."
else
    log_ok "All $total Homebrew packages installed"
fi

# gettext (envsubst) and coreutils are keg-only — put them on PATH so the
# theme engine and any GNU-tool assumptions resolve for this run.
export PATH="$(brew --prefix gettext)/bin:$(brew --prefix coreutils)/libexec/gnubin:$PATH"

# ─── 2. Stow the cross-platform config packages ───
#
# Only the portable packages — Linux-only ones (hypr, cliphist, wireplumber,
# arche-scripts, …) are intentionally skipped.

DARWIN_STOW_PKGS=(fish nvim ghostty tmux mpv btop glow)

log_info "Stowing cross-platform config packages..."
for pkg in "${DARWIN_STOW_PKGS[@]}"; do
    stow_pkg "$pkg"
done

# ─── 3. Set fish as the default login shell ───

# brew installs fish to $(brew --prefix)/bin/fish — resolve the real path
# (Homebrew, not any stray /usr/local copy) so /etc/shells and the login
# shell point at the same binary.
fish_path="$(command -v fish || true)"
if [[ -n "$fish_path" ]]; then
    # macOS only allows shells listed in /etc/shells as a login shell.
    if ! grep -qx "$fish_path" /etc/shells; then
        log_info "Adding fish to /etc/shells (needs sudo)..."
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # UserShell lives in the local Directory Service on macOS; read it there,
    # not from $SHELL (which reflects the *current* process, not the default).
    current_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    if [[ "$current_shell" != "$fish_path" ]]; then
        log_info "Setting fish as the login shell..."
        # sudo chsh reuses the cached sudo credential from above — no second
        # prompt — and works for the standard local account on macOS Tahoe.
        sudo chsh -s "$fish_path" "$USER"
        log_ok "Default shell set to fish (takes effect in a new terminal)"
    else
        log_warn "Fish already default shell"
    fi
else
    log_err "fish not found after install"
fi

# ─── 4. Fisher + plugins (from upstream, not a package) ───

if command -v fish &>/dev/null; then
    if [[ ! -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        log_info "Installing fisher from upstream..."
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
        log_ok "Fisher installed"
    else
        log_warn "Fisher already installed"
    fi
    log_info "Updating fisher plugins..."
    fish -c 'fisher update' 2>/dev/null || true
fi

# ─── 5. Render the active theme (cross-platform components only) ───
#
# ghostty/tmux/btop/starship/fish/glow/mpv configs reference generated theme
# files, so this step is what makes them actually work. Linux-only components
# (hypr, dms, gtk, fontconfig, legion, …) are not rendered.

if [[ ! -e "$ARCHE/theming/themes/active" ]]; then
    log_warn "No active theme — defaulting to ember"
    ln -sfn ember.sh "$ARCHE/theming/themes/active"
fi

log_info "Rendering theme..."
bash "$ARCHE/theming/engine.sh" apply ghostty fish starship tmux btop glow mpv

echo
log_ok "macOS bootstrap complete!"
log_info "Open a new terminal (or run 'exec fish') to pick up the new shell."
