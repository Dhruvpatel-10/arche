#!/usr/bin/env bash
# 10-appearance.sh — fonts, icons, cursors, GTK/Qt theming tools
source "$(dirname "$0")/lib.sh"

log_info "Setting up appearance..."
install_group "$ARCHE/packages/appearance.sh"

# Stow Qt theming configs (Kvantum + Qt6ct color palette)
stow_pkg kvantum
stow_pkg qt6ct

# Rebuild font cache after installing new fonts
if command -v fc-cache &>/dev/null; then
    log_info "Rebuilding font cache..."
    fc-cache -f
    log_ok "Font cache updated"
fi

# Render appearance templates (GTK settings, Qt6ct config)
theme_render gtk-3.0 gtk-4.0 qt6ct

log_ok "Appearance setup done"
