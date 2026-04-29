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

# Ensure early KMS on the kernel cmdline. nvidia_drm.modeset=1 is the
# modesetting driver prereq for Wayland (Hyprland).
if ! grep -q "nvidia_drm.modeset=1" /etc/kernel/cmdline 2>/dev/null; then
    log_warn "nvidia_drm.modeset=1 missing from /etc/kernel/cmdline"
    log_info "  /etc/kernel/cmdline is symlinked from system/etc/kernel/cmdline in the repo."
    log_info "  Add 'nvidia_drm.modeset=1' there, then re-run 'just boot'."
else
    log_ok "nvidia_drm.modeset=1 present on cmdline"
fi

# Enable VRAM save/restore services. Paired with NVreg_PreserveVideoMemoryAllocations=1
# (linked in from system/etc/modprobe.d/nvidia.conf by link_system_all). Without these,
# DPMS off → wake and suspend → wake leave the eDP panel black on Turing+ open-driver
# laptops. Services are shipped by nvidia-utils; they're disabled by default.
for svc in nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        log_warn "$svc already enabled"
    else
        sudo systemctl enable "$svc" >/dev/null 2>&1 && log_ok "Enabled: $svc"
    fi
done

# modprobe.d changes only take effect after the nvidia module reloads — and
# since nvidia is in MODULES=(), it's loaded from the UKI at boot, so the UKI
# must be rebuilt to embed the new options file.
if [[ -f /etc/modprobe.d/nvidia.conf ]] && ! sudo lsinitcpio /boot/EFI/Linux/arch-linux.efi 2>/dev/null | grep -q 'modprobe.d/nvidia.conf'; then
    log_info "Rebuilding initramfs to embed modprobe.d/nvidia.conf..."
    sudo mkinitcpio -P
    log_ok "UKI rebuilt with nvidia modprobe options"
fi

# Verify nvidia-smi
if command -v nvidia-smi &>/dev/null; then
    log_ok "nvidia-smi available"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true
else
    log_warn "nvidia-smi not found — reboot may be needed"
fi

log_ok "GPU setup done"
