#!/usr/bin/env bash
# 01-base.sh — install core system packages
source "$(dirname "$0")/lib.sh"

log_info "Installing base packages..."
install_group "$ARCHE/packages/base.sh"

log_ok "Base packages done"
