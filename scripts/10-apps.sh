#!/usr/bin/env bash
# 10-apps.sh — desktop applications and tools
source "$(dirname "$0")/lib.sh"

log_info "Installing applications..."
install_group "$ARCHE/packages/apps.sh"

# ─── Docker (rootless) ───
# Rootless docker runs the daemon as your user — no docker group needed.
# The docker group grants root-equivalent access; rootless avoids that entirely.

svc_enable docker

if ! systemctl --user is-active docker &>/dev/null; then
    if command -v dockerd-rootless-setuptool.sh &>/dev/null; then
        log_info "Setting up rootless docker..."
        dockerd-rootless-setuptool.sh install 2>/dev/null
        systemctl --user enable docker
        systemctl --user start docker
        log_ok "Rootless docker active — no docker group needed"
    else
        log_warn "dockerd-rootless-setuptool.sh not found — install docker-rootless-extras"
        log_info "Falling back to system docker (requires sudo)"
    fi
else
    log_warn "Rootless docker already running"
fi

# Remove user from docker group if present (no longer needed with rootless)
if groups "$USER" 2>/dev/null | grep -q docker; then
    log_info "Removing $USER from docker group (rootless doesn't need it)..."
    sudo gpasswd -d "$USER" docker 2>/dev/null
    log_ok "Removed from docker group — using rootless instead"
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
