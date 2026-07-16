#!/usr/bin/env bash
# core/lib.sh — portable primitives shared by every arche profile.
#
# This is the platform-agnostic core. It provides logging, stow, the shared
# setup helpers, and it wires in the right platform adapter (Arch, macOS, ...)
# plus the package registry. Anything that needs pacman, systemd, /etc, brew,
# launchd, etc. lives in core/adapters/<platform>.sh, never here.
#
# Kept bash 3.2 compatible on purpose: macOS still ships bash 3.2, so no
# associative arrays and no mapfile in this file or anything it sources on Mac.
#
# Usage from a step or tool:  source "$ARCHE/core/lib.sh"

set -euo pipefail

# Repo root. Every entrypoint exports ARCHE; fall back to this file's location.
ARCHE="${ARCHE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ARCHE

# Optional secrets (NextDNS id, etc). Never tracked in git.
[[ -f "$ARCHE/secrets.sh" ]] && source "$ARCHE/secrets.sh"

# ─── Logging ───
# Plain, readable output for a normal user. No jargon in the messages callers
# pass in. Colors degrade to nothing on dumb terminals.

ARCHE_LOG_FILE=""

log_init() {
    [[ -n "$ARCHE_LOG_FILE" ]] && return 0
    local log_dir="$ARCHE/logs"
    mkdir -p "$log_dir"
    ARCHE_LOG_FILE="$log_dir/$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$ARCHE_LOG_FILE"))
    exec 2> >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$ARCHE_LOG_FILE") >&2)
    export ARCHE_LOG_FILE
}

log_info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_ok()      { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
log_warn()    { printf '\033[1;33m[SKIP]\033[0m %s\n' "$*"; }
log_err()     { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; }
log_step()    { printf '\n\033[1;36m>> %s\033[0m\n\n' "$*"; }
# Back-compat alias for older scripts that used log_section.
log_section() { log_step "$@"; }

# ─── Platform detection + adapter ───
# arche_platform prints one of: arch, macos, linux (non-Arch), unknown.

arche_platform() {
    case "$(uname -s)" in
        Linux)
            if [[ -f /etc/arch-release ]]; then echo arch; else echo linux; fi
            ;;
        Darwin) echo macos ;;
        *)      echo unknown ;;
    esac
}

ARCHE_PLATFORM="${ARCHE_PLATFORM:-$(arche_platform)}"
export ARCHE_PLATFORM

# Load the adapter for this platform. It defines the package/service/system
# primitives (pkg_backend, svc_enable, link_system_*, read_login_shell,
# arche_root). Logging must already be defined above, adapters use it.
_arche_adapter="$ARCHE/core/adapters/${ARCHE_PLATFORM}.sh"
if [[ -f "$_arche_adapter" ]]; then
    # shellcheck source=/dev/null
    source "$_arche_adapter"
else
    log_warn "No platform adapter for '$ARCHE_PLATFORM' — package and service steps will be skipped"
fi

# Load the package registry (tool DSL parser + resolver).
# shellcheck source=/dev/null
source "$ARCHE/core/registry.sh"

# ─── Stow ───
# Symlink one stow package into $HOME. Cleans broken links and backs up any
# real file that would conflict (suffix .pre-stow), so it is safe to re-run.

stow_pkg() {
    local pkg="$1"
    local stow_dir="$ARCHE/stow"

    if [[ ! -d "$stow_dir/$pkg" ]]; then
        log_err "Config package not found: $stow_dir/$pkg"
        return 1
    fi

    while IFS= read -r -d '' target; do
        local rel="${target#"$stow_dir"/"$pkg"/}"
        local dest="$HOME/$rel"
        if [[ -L "$dest" && ! -e "$dest" ]]; then
            rm -f "$dest"
            log_info "Removed a broken old link: $dest"
        fi
    done < <(find "$stow_dir/$pkg" -type f -print0)

    if ! stow -d "$stow_dir" -t "$HOME" --no-folding -n "$pkg" 2>/dev/null; then
        log_warn "Some files already exist for $pkg, backing them up and replacing"
        while IFS= read -r -d '' src; do
            local rel="${src#"$stow_dir"/"$pkg"/}"
            local dest="$HOME/$rel"
            if [[ -e "$dest" && ! -L "$dest" ]]; then
                mv "$dest" "${dest}.pre-stow"
                log_info "Backed up: $rel (saved as $rel.pre-stow)"
            elif [[ -L "$dest" ]]; then
                rm -f "$dest"
            fi
        done < <(find "$stow_dir/$pkg" -type f -print0)
        stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg"
        log_ok "Linked config: $pkg"
        return 0
    fi

    stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg"
    log_ok "Linked config: $pkg"
}

# Remove one stow package's links from $HOME (used by the clean command).
unstow_pkg() {
    local pkg="$1"
    local stow_dir="$ARCHE/stow"
    [[ -d "$stow_dir/$pkg" ]] || { log_warn "No such config package: $pkg"; return 0; }
    stow -d "$stow_dir" -t "$HOME" --no-folding -D "$pkg" 2>/dev/null || true
    log_ok "Unlinked config: $pkg"
}

# ─── Shared setup helpers (portable) ───

# Make <shell_path> the user's login shell. Uses the adapter's read_login_shell
# so it works with both getent (Linux) and dscl (macOS).
set_login_shell() {
    local shell_path="$1"
    [[ -x "$shell_path" ]] || { log_err "Shell not found: $shell_path"; return 1; }

    if ! grep -qx "$shell_path" /etc/shells 2>/dev/null; then
        log_info "Allowing $shell_path as a login shell"
        echo "$shell_path" | sudo tee -a /etc/shells >/dev/null
    fi

    local current=""
    if command -v read_login_shell >/dev/null 2>&1; then
        current="$(read_login_shell)"
    fi
    if [[ "$current" != "$shell_path" ]]; then
        log_info "Setting your default shell to $shell_path"
        sudo chsh -s "$shell_path" "$USER"
        log_ok "Default shell changed. Open a new terminal to use it."
    else
        log_warn "Default shell is already $shell_path"
    fi
}

# Install fisher (fish plugin manager) from upstream and update plugins.
setup_fisher() {
    command -v fish >/dev/null || { log_warn "fish is not installed, skipping fisher"; return 0; }
    if [[ ! -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        log_info "Installing fisher, the fish plugin manager"
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
        log_ok "fisher installed"
    else
        log_warn "fisher already installed"
    fi
    log_info "Updating fish plugins"
    fish -c 'fisher update' 2>/dev/null || true
}

# Compute a file's sha256 with whatever tool the platform has.
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# Download an installer script and run it, verifying its checksum first.
# Usage: curl_install_checked <url> <sha256|-> [interpreter]
# Pass "-" as the checksum to skip verification (logs a clear warning), for
# upstreams that only publish a moving "latest" installer.
curl_install_checked() {
    local url="$1" want="$2" interp="${3:-bash}"
    local tmp; tmp="$(mktemp)"
    log_info "Downloading installer: $url"
    if ! curl -fsSL "$url" -o "$tmp"; then
        log_err "Could not download $url"
        rm -f "$tmp"; return 1
    fi
    if [[ "$want" == "-" ]]; then
        log_warn "Running installer without a checksum (upstream ships a moving installer)"
    else
        local got; got="$(_sha256 "$tmp")"
        if [[ "$got" != "$want" ]]; then
            log_err "Checksum did not match for $url"
            log_err "  expected: $want"
            log_err "  got:      $got"
            rm -f "$tmp"; return 1
        fi
        log_ok "Installer checksum verified"
    fi
    "$interp" "$tmp"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

# Pick the platform-specific variant of a config that uses the include-a-symlink
# pattern (see stow/mpv). Both variants ship in the stow package; this flips the
# uncommitted selector symlink to the right one for this OS.
# Usage: select_platform_variant <symlink_path> <linux_variant> <macos_variant>
select_platform_variant() {
    local link="$1" linux_v="$2" macos_v="$3"
    [[ -d "$(dirname "$link")" ]] || return 0
    local chosen
    case "$ARCHE_PLATFORM" in
        macos) chosen="$macos_v" ;;
        *)     chosen="$linux_v" ;;
    esac
    ln -sfn "$chosen" "$link"
    log_ok "Selected $(basename "$link") for $ARCHE_PLATFORM"
}

# ─── Theme engine ───
# The theme functions (theme_validate, theme_render, _theme_apply_gsettings)
# are portable and live in theming/theme-lib.sh. Load them here so every step
# that sources core/lib.sh can render themes.
# shellcheck source=/dev/null
source "$ARCHE/theming/theme-lib.sh"
