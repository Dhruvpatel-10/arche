#!/usr/bin/env bash
# 07-panel.sh — Quickshell panel + arche-shell clone
source "$(dirname "$0")/lib.sh"

log_info "Setting up Quickshell panel..."
install_group "$ARCHE/packages/panel.sh"

# ─── Clone (or update) arche-shell ───
# The QML source lives outside the arche repo so it can be iterated on
# independently and hot-reloaded on save. See D023.
shell_repo="https://github.com/Dhruvpatel-10/quickshell.git"
shell_dst="$HOME/projects/system/arche-shell"

if [[ ! -d "$shell_dst/.git" ]]; then
    log_info "Cloning arche-shell to $shell_dst..."
    mkdir -p "$(dirname "$shell_dst")"
    git clone "$shell_repo" "$shell_dst"
    log_ok "Cloned arche-shell"
else
    log_info "Pulling arche-shell..."
    git -C "$shell_dst" pull --ff-only || log_warn "arche-shell pull failed — leaving as-is"
fi

# ─── Symlink ~/.config/quickshell → arche-shell clone ───
config_target="$HOME/.config/quickshell"
if [[ -L "$config_target" ]]; then
    current="$(readlink -f "$config_target")"
    if [[ "$current" != "$shell_dst" ]]; then
        log_info "Updating $config_target symlink → $shell_dst"
        ln -sfn "$shell_dst" "$config_target"
    fi
elif [[ -e "$config_target" ]]; then
    log_warn "$config_target exists and is not a symlink — leaving untouched"
else
    mkdir -p "$(dirname "$config_target")"
    ln -s "$shell_dst" "$config_target"
    log_ok "Linked $config_target → $shell_dst"
fi

log_ok "Quickshell panel setup done"
