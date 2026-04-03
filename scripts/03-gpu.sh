#!/usr/bin/env bash
# 03-gpu.sh — NVIDIA open kernel module + CUDA
source "$(dirname "$0")/lib.sh"

# Skip entirely if no NVIDIA GPU detected
if ! lspci 2>/dev/null | grep -qi nvidia; then
    log_warn "No NVIDIA GPU detected — skipping"
    exit 0
fi

log_info "Setting up NVIDIA GPU..."
install_group "$ARCHE/packages/gpu-nvidia.sh"

# Ensure nvidia modules are in initramfs for early KMS
mkinitcpio_conf="/etc/mkinitcpio.conf"
required_modules=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

if grep -q "MODULES=.*nvidia" "$mkinitcpio_conf" 2>/dev/null; then
    log_warn "NVIDIA modules already in mkinitcpio.conf"
else
    log_info "Adding NVIDIA modules to mkinitcpio.conf..."

    # Read current MODULES=(...) line and append nvidia modules
    current_modules=$(grep '^MODULES=' "$mkinitcpio_conf" | sed 's/MODULES=(\(.*\))/\1/')
    new_modules="$current_modules ${required_modules[*]}"
    # Normalize whitespace
    new_modules=$(echo "$new_modules" | xargs)

    sudo sed -i "s/^MODULES=(.*/MODULES=($new_modules)/" "$mkinitcpio_conf"
    log_ok "Added to MODULES: ${required_modules[*]}"

    # Rebuild initramfs
    log_info "Rebuilding initramfs (mkinitcpio -P)..."
    sudo mkinitcpio -P
    log_ok "Initramfs rebuilt with NVIDIA modules"
fi

# Ensure DRM modeset is enabled (needed for Wayland)
if ! grep -q "nvidia_drm.modeset=1" /proc/cmdline 2>/dev/null; then
    log_warn "nvidia_drm.modeset=1 not in kernel cmdline"
    log_info "Add to your Limine bootloader config:"
    log_info "  CMDLINE=... nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
fi

# Verify nvidia-smi
if command -v nvidia-smi &>/dev/null; then
    log_ok "nvidia-smi available"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
else
    log_warn "nvidia-smi not found — reboot may be needed"
fi

log_ok "GPU setup done"
