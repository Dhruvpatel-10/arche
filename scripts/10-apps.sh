#!/usr/bin/env bash
# 10-apps.sh — desktop applications and tools
source "$(dirname "$0")/lib.sh"

log_info "Installing applications..."
install_group "$ARCHE/packages/apps.sh"

# Enable Docker
svc_enable docker

# Add user to docker group if not already
if ! groups "$USER" | grep -q docker; then
    log_info "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    log_warn "Relogin needed for docker group"
else
    log_warn "$USER already in docker group"
fi

# Enable Syncthing user service
svc_enable --user syncthing

# Enable Bluetooth
svc_enable bluetooth

# Stow app configs
for pkg in mpv zathura yazi mimeapps; do
    if [[ -d "$ARCHE/stow/$pkg" ]]; then
        stow_pkg "$pkg"
    else
        log_warn "stow/$pkg not found — skipping"
    fi
done

# Install yazi plugins from package.toml
if command -v ya &>/dev/null; then
    log_info "Installing yazi plugins..."
    ya pkg install 2>/dev/null && log_ok "Yazi plugins installed"
else
    log_warn "ya not found — skipping yazi plugin install"
fi

log_ok "Applications setup done"
