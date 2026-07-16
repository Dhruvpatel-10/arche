#!/usr/bin/env bash
# core/adapters/macos.sh — macOS (Apple Silicon) platform adapter.
#
# Implements the same primitives the Arch adapter does, backed by Homebrew and
# the macOS directory service. Service management and /etc linking are Linux
# concepts, so they are safe no-ops here (profiles never call them on macOS,
# but keeping them defined means shared steps cannot crash).

# Make sure brew is on PATH (fresh machine, user has not opened a new shell yet).
if ! command -v brew >/dev/null 2>&1 && [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install one or more Homebrew packages of a channel, skipping installed ones.
# _brew_install <--formula|--cask> <pkg...>
_brew_install() {
    local flag="$1"; shift
    local listkind="formula"; [[ "$flag" == "--cask" ]] && listkind="cask"
    export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1
    local pkg
    for pkg in "$@"; do
        if brew list "--$listkind" --versions "$pkg" >/dev/null 2>&1; then
            log_warn "$pkg already installed"
        else
            log_info "Installing $pkg"
            brew install "$flag" "$pkg" || log_err "Could not install $pkg"
        fi
    done
}

# ─── Adapter interface (called by the core) ───

# Install packages of a given kind. Kinds on macOS: brew (formula), cask.
pkg_backend() {
    local kind="$1"; shift
    case "$kind" in
        brew) _brew_install --formula "$@" ;;
        cask) _brew_install --cask "$@" ;;
        *) log_err "macos adapter: unknown package kind '$kind'"; return 1 ;;
    esac
}

# macOS has no systemd. Left as a clear no-op until (if) we wire brew services
# or launchd per service, so shared steps can call it without failing.
svc_enable() {
    local args="$*"
    log_warn "Background services are not managed on macOS yet, skipping: ${args:-service}"
}

# macOS does not use the /etc symlink deployment model.
link_system_file() { log_warn "System files are Linux only, skipping on macOS"; }
link_system_all()  { :; }

# Read the user's login shell from the macOS local directory service (dscl),
# not $SHELL (which reflects the current process, not the stored default).
read_login_shell() {
    dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
}

# Single-user Mac: the repo lives in the home directory, no shared /opt group.
arche_root() { echo "$HOME/arche"; }
