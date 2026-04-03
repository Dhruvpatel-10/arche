#!/usr/bin/env bash
# 07-bar.sh — Waybar status bar
source "$(dirname "$0")/lib.sh"

log_info "Setting up Waybar..."
install_group "$ARCHE/packages/bar.sh"

stow_pkg waybar

log_ok "Waybar setup done"
