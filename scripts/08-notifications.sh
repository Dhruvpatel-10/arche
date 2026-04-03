#!/usr/bin/env bash
# 08-notifications.sh — mako notification daemon
source "$(dirname "$0")/lib.sh"

log_info "Setting up notifications..."
install_group "$ARCHE/packages/notifications.sh"

# mako is template-only (no behavior config in stow)
# Visual config rendered by theme.sh from templates/mako/config.tmpl

log_ok "Notifications setup done"
