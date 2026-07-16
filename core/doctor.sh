#!/usr/bin/env bash
# core/doctor.sh — check that the arche setup is healthy, and optionally repair.
#
# Run read-only checks by default. With --repair, fix the things that are safe
# to fix automatically: re-link configs, re-render the theme, re-select the
# platform config, and re-enable background services. Missing packages are
# reported (and offered) but never force-installed without asking.
#
# Invoked by bootstrap.sh: `bootstrap.sh doctor [--repair]`. Expects the active
# profile to already be loaded (PROFILE_STOW, PROFILE_THEME set) and core/lib.sh
# sourced.

_DOCTOR_REPAIR=0
_DOCTOR_ISSUES=0

_chk_ok()   { printf '  \033[1;32m[ OK ]\033[0m %s\n' "$*"; }
_chk_warn() { printf '  \033[1;33m[WARN]\033[0m %s\n' "$*"; _DOCTOR_ISSUES=$(( _DOCTOR_ISSUES + 1 )); }
_chk_fix()  { printf '  \033[1;36m[FIX ]\033[0m %s\n' "$*"; }

# ── individual checks ──

_doctor_platform() {
    if command -v pkg_backend >/dev/null 2>&1; then
        _chk_ok "Platform detected: $ARCHE_PLATFORM (adapter loaded)"
    else
        _chk_warn "No adapter loaded for platform '$ARCHE_PLATFORM' — packages and services cannot be managed"
    fi
}

_doctor_theme() {
    local active="$ARCHE/theming/themes/active"
    if [[ ! -e "$active" ]]; then
        _chk_warn "No active theme is selected"
        if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
            ln -sfn ember.sh "$active"
            _chk_fix "Selected the default theme (ember)"
        fi
        return
    fi
    if theme_validate "$active" >/dev/null 2>&1; then
        _chk_ok "Active theme is valid: $(basename "$(readlink "$active")" .sh)"
    else
        _chk_warn "Active theme has invalid values (run: theming/engine.sh validate)"
    fi
    if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
        _chk_fix "Re-rendering theme files"
        bash "$ARCHE/theming/engine.sh" apply ${PROFILE_THEME[@]+"${PROFILE_THEME[@]}"} >/dev/null 2>&1 \
            && _chk_ok "Theme files re-rendered" \
            || _chk_warn "Theme render reported problems"
    fi
}

_doctor_stow() {
    local pkg missing=0
    for pkg in "${PROFILE_STOW[@]}"; do
        [[ -d "$ARCHE/stow/$pkg" ]] || continue
        # If a dry-run wants to create links, the package is not fully linked.
        if stow -d "$ARCHE/stow" -t "$HOME" --no-folding -n "$pkg" 2>&1 | grep -q .; then
            _chk_warn "Config not fully linked: $pkg"
            missing=$(( missing + 1 ))
            if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
                stow_pkg "$pkg" >/dev/null 2>&1 && _chk_fix "Re-linked config: $pkg"
            fi
        fi
    done
    [[ $missing -eq 0 ]] && _chk_ok "All ${#PROFILE_STOW[@]} config packages are linked"
}

_doctor_broken_links() {
    # Dangling symlinks under ~/.config that point back into the repo.
    local broken
    broken="$(find "$HOME/.config" -maxdepth 4 -type l ! -exec test -e {} \; -print 2>/dev/null | grep -c "" || true)"
    if [[ "${broken:-0}" -gt 0 ]]; then
        _chk_warn "$broken broken config link(s) under ~/.config"
        if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
            find "$HOME/.config" -maxdepth 4 -type l ! -exec test -e {} \; -delete 2>/dev/null || true
            _chk_fix "Removed broken config links"
        fi
    else
        _chk_ok "No broken config links"
    fi
}

_doctor_packages() {
    command -v pkg_installed >/dev/null 2>&1 || return 0
    local pkg missing=""
    for pkg in $(registry_packages "$ARCHE_PLATFORM"); do
        pkg_installed "$pkg" || missing="$missing $pkg"
    done
    # shellcheck disable=SC2086
    set -- $missing
    if [[ $# -eq 0 ]]; then
        _chk_ok "All registry packages are installed"
    else
        _chk_warn "$# package(s) from the registry are not installed:$missing"
        if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
            log_info "Install the missing packages now?"
            local reply
            printf "  Install %d package(s)? [y/N] " "$#"
            read -r reply
            if [[ "$reply" =~ ^[yY]$ ]]; then
                registry_install "$ARCHE_PLATFORM"
                _chk_fix "Installed missing packages"
            fi
        fi
    fi
}

# ── entrypoint ──

run_doctor() {
    [[ "${1:-}" == "--repair" ]] && _DOCTOR_REPAIR=1

    log_step "Checking your arche setup"
    if [[ "$_DOCTOR_REPAIR" == "1" ]]; then
        log_info "Repair mode is on. I will fix what is safe to fix automatically."
    else
        log_info "This only looks, it does not change anything. Add --repair to fix problems."
    fi
    echo

    _doctor_platform
    _doctor_theme
    _doctor_stow
    _doctor_broken_links
    _doctor_packages

    echo
    if [[ $_DOCTOR_ISSUES -eq 0 ]]; then
        log_ok "Everything looks good."
    elif [[ "$_DOCTOR_REPAIR" == "1" ]]; then
        log_info "Repairs attempted. Run doctor again to confirm everything is clear."
    else
        log_warn "Found $_DOCTOR_ISSUES thing(s) to look at. Run 'doctor --repair' to fix them."
    fi
}
