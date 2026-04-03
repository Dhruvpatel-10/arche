#!/usr/bin/env bash
# 05-hyprland.sh — Hyprland compositor + Wayland utilities
source "$(dirname "$0")/lib.sh"

log_info "Setting up Hyprland..."
install_group "$ARCHE/packages/hyprland.sh"

# Link greetd config and greeter binary, then enable
link_system_file "$ARCHE/system/etc/greetd/config.toml" "/etc/greetd/config.toml"
link_system_file "$ARCHE/tools/bin/arche-greeter" "/usr/local/bin/arche-greeter"
svc_enable greetd

# Stow configs
stow_pkg hypr
stow_pkg rofi

# Deploy arche-legion binary (symlink so updates propagate)
mkdir -p "$HOME/.local/bin/arche"
ln -sf "$ARCHE/tools/bin/arche-legion" "$HOME/.local/bin/arche/arche-legion"
log_ok "Linked arche-legion"

log_ok "Hyprland setup done"
