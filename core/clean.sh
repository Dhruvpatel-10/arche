#!/usr/bin/env bash
# core/clean.sh — undo the arche setup, in safe tiers.
#
# Default (safe): unlink the config files it created and remove the platform
# selector links. This does not touch your installed programs or the repo, so
# you can re-run the installer any time to put everything back.
#
#   bootstrap.sh clean              # unlink configs only (safe, reversible)
#   bootstrap.sh clean --system     # also remove system files it linked (Linux)
#   bootstrap.sh clean --packages   # also remove the programs it installed (asks first)
#
# Expects the active profile loaded (PROFILE_STOW) and core/lib.sh sourced.

_clean_confirm() {
    [[ "${ARCHE_YES:-0}" == "1" ]] && return 0
    local reply
    printf "  %s [y/N] " "$1"
    read -r reply
    [[ "$reply" =~ ^[yY]$ ]]
}

_clean_configs() {
    log_step "Unlinking config files"
    local pkg
    for pkg in "${PROFILE_STOW[@]}"; do
        [[ -d "$ARCHE/stow/$pkg" ]] || continue
        unstow_pkg "$pkg"
    done
    # Remove the uncommitted platform selector links (e.g. mpv/platform.conf).
    local sel="$HOME/.config/mpv/platform.conf"
    [[ -L "$sel" ]] && { rm -f "$sel"; log_ok "Removed platform selector: mpv/platform.conf"; }
    log_info "Your installed programs and the repo were left untouched."
}

_clean_system() {
    if [[ "$ARCHE_PLATFORM" == "macos" ]]; then
        log_warn "There are no system files to remove on macOS. Skipping."
        return 0
    fi
    log_step "Removing system files"
    log_warn "This unlinks the files arche placed under /etc and /usr/local."
    log_warn "Your firewall, boot, and service configs will fall back to defaults."
    _clean_confirm "Remove system files now?" || { log_info "Skipped system files."; return 0; }
    local sys_dir="$ARCHE/system" src rel
    while IFS= read -r -d '' src; do
        rel="${src#"$sys_dir"}"
        if [[ -L "$rel" ]]; then
            sudo rm -f "$rel" && log_ok "Removed: $rel"
        fi
    done < <(find "$sys_dir" \( -type f -o -type l \) -print0 2>/dev/null)
}

_clean_packages() {
    command -v pkg_backend >/dev/null 2>&1 || { log_warn "No adapter, cannot remove packages."; return 0; }
    log_step "Removing installed programs"
    log_warn "This removes the programs arche installed from the registry."
    log_warn "This is the most destructive option. Shared system tools may go with them."
    _clean_confirm "Remove installed programs now?" || { log_info "Skipped removing programs."; return 0; }

    local pkgs; pkgs="$(registry_packages "$ARCHE_PLATFORM")"
    # shellcheck disable=SC2086
    set -- $pkgs
    log_info "Would remove $# package(s)."
    case "$ARCHE_PLATFORM" in
        arch)
            log_warn "Review this list, then remove manually so pacman can resolve dependencies safely:"
            echo "  paru -Rns $*"
            log_info "arche does not auto-remove pacman packages (removal order matters)."
            ;;
        macos)
            local p
            for p in "$@"; do
                brew uninstall "$p" 2>/dev/null && log_ok "Removed: $p" || log_warn "Skipped: $p"
            done
            ;;
    esac
}

run_clean() {
    local do_system=0 do_packages=0 arg
    for arg in "$@"; do
        case "$arg" in
            --system)   do_system=1 ;;
            --packages) do_packages=1 ;;
            --all)      do_system=1; do_packages=1 ;;
        esac
    done

    log_step "Cleaning up the arche setup"
    log_info "Config files will be unlinked. Programs and the repo stay unless you ask."
    echo

    _clean_configs
    [[ "$do_system" == "1" ]]   && _clean_system
    [[ "$do_packages" == "1" ]] && _clean_packages

    echo
    log_ok "Done. Re-run the installer any time to set everything back up."
}
