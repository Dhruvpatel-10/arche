#!/usr/bin/env bash
# 09-apps.sh — desktop applications and tools
source "$(dirname "$0")/lib.sh"

log_info "Installing applications..."
install_group "$ARCHE/packages/apps.sh"

# ─── Docker ───
# Rootless is preferred (daemon runs as your user, no docker group needed),
# but `dockerd-rootless-setuptool.sh` is no longer packaged by Arch since
# Docker 29. If the user has fetched it manually from upstream, we'll use it;
# otherwise fall back to system docker (requires sudo to run `docker ...`).

svc_enable docker

if ! systemctl --user is-active docker &>/dev/null; then
    if command -v dockerd-rootless-setuptool.sh &>/dev/null; then
        log_info "Setting up rootless docker..."
        dockerd-rootless-setuptool.sh install 2>/dev/null
        systemctl --user enable docker
        systemctl --user start docker
        log_ok "Rootless docker active — no docker group needed"
    else
        log_warn "dockerd-rootless-setuptool.sh not found (not packaged since Docker 29)"
        log_info "Using system docker. For rootless, fetch the setuptool from upstream:"
        log_info "  https://github.com/moby/moby/blob/master/contrib/dockerd-rootless-setuptool.sh"
    fi
else
    log_warn "Rootless docker already running"
fi

# Remove user from docker group if present (rootless doesn't need it; for
# system docker the user should authenticate via sudo rather than join the
# docker group, which grants root-equivalent access).
if groups "$USER" 2>/dev/null | grep -q docker; then
    log_info "Removing $USER from docker group (use sudo for system docker)..."
    sudo gpasswd -d "$USER" docker 2>/dev/null
    log_ok "Removed from docker group"
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
for pkg in mpv zathura mimeapps; do
    if [[ -d "$ARCHE/stow/$pkg" ]]; then
        stow_pkg "$pkg"
    else
        log_warn "stow/$pkg not found — skipping"
    fi
done

# ─── Arche-Denoise (GPU noise suppression) ───
# Two binaries, same source tree, both deployed system-wide:
#   arche-denoise      — Rust CLI (file/pipe denoise, setup, status)
#   arche-denoise-mic  — C daemon (PipeWire virtual mic, run by user systemd unit)
# Binaries are symlinked into /usr/local/bin/arche/ declaratively via system/
# (handled by link_system_all in 00-preflight.sh). SDK lives system-wide at
# /usr/local/share/arche/denoise/ so every user shares one install.
DENOISE_CLI="/usr/local/bin/arche/arche-denoise"
DENOISE_SDK_SRC="$HOME/projects/system/arche-denoise/sdk/maxine_linux_audio_effects_sdk_v2.1.0/Audio_Effects_SDK"
DENOISE_MODEL_SRC="$HOME/projects/system/arche-denoise/sdk/afx_denoiser_v2.1.0-48k-sm89/denoiser_48k_6656.trtpkg"
DENOISE_SDK_DIR="/usr/local/share/arche/denoise"

if [[ -x "$DENOISE_CLI" && -x /usr/local/bin/arche/arche-denoise-mic ]]; then
    stow_pkg arche-denoise

    # Install SDK system-wide if not already present
    if [[ ! -f "$DENOISE_SDK_DIR/lib/libnv_audiofx.so" ]]; then
        if [[ -d "$DENOISE_SDK_SRC" ]]; then
            log_info "Installing Maxine SDK to $DENOISE_SDK_DIR..."
            if sudo "$DENOISE_CLI" setup --system \
                --sdk-path "$DENOISE_SDK_SRC" \
                --model "$DENOISE_MODEL_SRC"; then
                log_ok "arche-denoise SDK installed system-wide"
            else
                log_warn "arche-denoise SDK setup failed"
            fi
        else
            log_warn "Maxine SDK source not found at $DENOISE_SDK_SRC — skipping setup"
        fi
    else
        log_warn "arche-denoise SDK already installed at $DENOISE_SDK_DIR"
    fi

    svc_enable --user arche-denoise
else
    log_warn "arche-denoise binaries not found — re-run 00-preflight.sh"
fi

log_ok "Applications setup done"
