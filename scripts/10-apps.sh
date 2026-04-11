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

# Enable Bluetooth — unblock rfkill soft-block before starting
# Lenovo Legion laptops soft-block hci0 on boot and after suspend.
# These services run rfkill unblock before bluetooth.service starts
# and again after resume from suspend.
link_system_file "$ARCHE/system/etc/systemd/system/bluetooth-rfkill-unblock.service" \
    "/etc/systemd/system/bluetooth-rfkill-unblock.service"
link_system_file "$ARCHE/system/etc/systemd/system/bluetooth-rfkill-unblock-resume.service" \
    "/etc/systemd/system/bluetooth-rfkill-unblock-resume.service"
svc_enable bluetooth-rfkill-unblock
svc_enable bluetooth-rfkill-unblock-resume
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

# ─── Arche-Denoise (GPU noise suppression) ───
# Single binary that creates a PipeWire virtual mic with Maxine GPU denoising.
# Binary lives in tools/bin/, stow package provides systemd service.
DENOISE_SDK="$HOME/projects/system/arche-denoise/sdk/maxine_linux_audio_effects_sdk_v2.1.0/Audio_Effects_SDK"
DENOISE_MODEL="$HOME/projects/system/arche-denoise/sdk/afx_denoiser_v2.1.0-48k-sm89/denoiser_48k_6656.trtpkg"
DENOISE_BIN="$HOME/.local/bin/arche/arche-denoise"

if [[ -x "$DENOISE_BIN" ]]; then
    stow_pkg arche-denoise

    # Run --setup if managed SDK dir doesn't exist yet
    if [[ ! -f "$HOME/.local/share/arche-denoise/lib/libnv_audiofx.so" ]]; then
        if [[ -d "$DENOISE_SDK" ]]; then
            log_info "Setting up arche-denoise SDK..."
            "$DENOISE_BIN" --setup --sdk-path "$DENOISE_SDK" --model "$DENOISE_MODEL" \
                && log_ok "arche-denoise SDK installed" \
                || log_warn "arche-denoise SDK setup failed"
        else
            log_warn "arche-denoise SDK not found at $DENOISE_SDK — skipping setup"
        fi
    else
        log_warn "arche-denoise SDK already set up"
    fi

    svc_enable --user arche-denoise
else
    log_warn "arche-denoise binary not found — skipping"
fi

log_ok "Applications setup done"
