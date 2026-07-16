#!/usr/bin/env bash
# core/adapters/arch.sh — Arch Linux platform adapter.
#
# Implements the package, service, and system-file primitives the core and
# profiles call through. The linking + package + service functions below are
# lifted unchanged from the old scripts/lib.sh; the adapter interface at the
# bottom (pkg_backend, read_login_shell, arche_root) is the new seam the
# platform-agnostic core talks to.

# ─── System File Linking ───

link_system_file() {
    local src="$1" dst="$2"

    if [[ ! -f "$src" ]]; then
        log_err "Source not found: $src"
        return 1
    fi

    # Resolve to the canonical path so the installed symlink targets
    # /opt/arche/… directly, not a per-user /home/<user>/arche symlink
    # (home dirs are mode 700 — services like sddm can't traverse them).
    src="$(readlink -f "$src")"

    # If an existing link's *literal* target goes through /home/, it's stale
    # (installed from a ~/arche clone before this was fixed) — force recreate.
    if [[ -L "$dst" ]]; then
        local literal
        literal="$(readlink "$dst")"
        if [[ "$literal" == "$src" ]]; then
            log_warn "Already linked: $dst"
            return 0
        fi
        if [[ "$literal" == /home/* ]]; then
            log_info "Repointing stale symlink via /home/: $dst"
            sudo rm -f "$dst"
        fi
    fi

    if [[ -f "$dst" && ! -L "$dst" ]]; then
        sudo cp "$dst" "${dst}.bak"
        log_info "Backed up original: ${dst}.bak"
    fi

    sudo mkdir -p "$(dirname "$dst")"
    sudo ln -sf "$src" "$dst"
    log_ok "Linked: $dst"
}

# Walk system/ tree and symlink every file to its / counterpart.
# system/etc/pacman.conf → /etc/pacman.conf
# system/usr/local/bin/foo → /usr/local/bin/foo (made executable)
# Symlinks in system/ (e.g. to tools/bin/*) are preserved as-is so that
# /usr/local/bin/arche/X → /opt/arche/system/usr/local/bin/arche/X → tools/bin/X.
link_system_all() {
    local sys_dir="$ARCHE/system"

    if [[ ! -d "$sys_dir" ]]; then
        log_err "system/ directory not found"
        return 1
    fi

    while IFS= read -r -d '' src; do
        local rel="${src#"$sys_dir"}"
        link_system_file "$src" "$rel"
        # Make scripts executable (follows symlinks — chmod on final target)
        if [[ "$rel" == /usr/local/bin/* ]]; then
            sudo chmod +x "$rel"
        fi
    done < <(find "$sys_dir" \( -type f -o -type l \) -print0)
}

# ─── Package Installation ───

pkg_install() {
    local pkg
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_warn "$pkg already installed"
        else
            log_info "Installing $pkg..."
            sudo pacman -S --needed "$pkg"
        fi
    done
}

aur_install() {
    local aur_helper=""
    if command -v paru &>/dev/null; then
        aur_helper="paru"
    elif command -v yay &>/dev/null; then
        aur_helper="yay"
    else
        log_err "No AUR helper found (paru or yay) — install one first"
        return 1
    fi

    local pkg
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_warn "$pkg already installed"
        else
            log_info "Installing $pkg from AUR via $aur_helper..."
            log_info "PKGBUILD: https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=$pkg"
            "$aur_helper" -S --needed "$pkg"
        fi
    done
}

install_group() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_err "Package file not found: $file"
        return 1
    fi

    # Reset arrays before sourcing
    PACMAN_PKGS=()
    AUR_PKGS=()

    # shellcheck source=/dev/null
    source "$file"

    if [[ ${#PACMAN_PKGS[@]} -gt 0 ]]; then
        log_info "Installing pacman packages from $(basename "$file")..."
        pkg_install "${PACMAN_PKGS[@]}"
    fi

    if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
        log_info "Installing AUR packages from $(basename "$file")..."
        aur_install "${AUR_PKGS[@]}"
    fi
}
# ─── Systemd Services ───

svc_enable() {
    local user_flag=""
    if [[ "${1:-}" == "--user" ]]; then
        user_flag="--user"
        shift
    fi

    local svc="$1"

    if systemctl ${user_flag:+"$user_flag"} is-active --quiet "$svc" 2>/dev/null; then
        log_warn "$svc already active"
    else
        log_info "Enabling $svc..."
        systemctl ${user_flag:+"$user_flag"} enable --now "$svc"
        log_ok "$svc enabled and started"
    fi
}


# ─── Adapter interface (called by the core) ───

# Install packages of a given kind. Kinds on Arch: pacman, aur.
pkg_backend() {
    local kind="$1"; shift
    case "$kind" in
        pacman) pkg_install "$@" ;;
        aur)    aur_install "$@" ;;
        *) log_err "arch adapter: unknown package kind '$kind'"; return 1 ;;
    esac
}

# Read the user's current login shell from the passwd database.
read_login_shell() {
    getent passwd "$USER" 2>/dev/null | cut -d: -f7
}

# Where the shared repo lives on this platform.
arche_root() { echo "/opt/arche"; }
