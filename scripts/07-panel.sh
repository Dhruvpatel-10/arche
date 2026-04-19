#!/usr/bin/env bash
# 07-panel.sh — Quickshell panel, sourced from /opt/arche/shell/
source "$(dirname "$0")/lib.sh"

log_info "Setting up Quickshell panel..."
install_group "$ARCHE/packages/panel.sh"

# ─── Symlink ~/.config/quickshell → /opt/arche/shell ───
# The QML source is vendored into the arche repo itself (D029, supersedes D023).
# One source of truth, no per-user clone, hot-reload on save still works.
shell_src="$ARCHE/shell"
config_target="$HOME/.config/quickshell"

if [[ ! -d "$shell_src" ]]; then
    log_err "Shell source missing: $shell_src"
    exit 1
fi

if [[ -L "$config_target" ]]; then
    current="$(readlink -f "$config_target")"
    if [[ "$current" != "$(readlink -f "$shell_src")" ]]; then
        log_info "Updating $config_target symlink → $shell_src"
        ln -sfn "$shell_src" "$config_target"
    else
        log_warn "Already linked: $config_target"
    fi
elif [[ -e "$config_target" ]]; then
    log_warn "$config_target exists and is not a symlink — leaving untouched"
else
    mkdir -p "$(dirname "$config_target")"
    ln -s "$shell_src" "$config_target"
    log_ok "Linked $config_target → $shell_src"
fi

log_ok "Quickshell panel setup done"
