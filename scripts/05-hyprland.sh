#!/usr/bin/env bash
# 05-hyprland.sh — Hyprland compositor + Wayland utilities + SDDM greeter
source "$(dirname "$0")/lib.sh"

log_info "Setting up Hyprland..."
install_group "$ARCHE/packages/hyprland.sh"

# ─── SDDM login manager ───
# Custom arche theme at /usr/share/sddm/themes/arche/ (symlinked from
# system/usr/share/sddm/themes/arche/ by link_system_all in 00-preflight.sh).
# Config at /etc/sddm.conf.d/10-arche.conf is symlinked by the same helper.
# Disable any legacy greeters left over from prior stacks.
for legacy in greetd.service greetd-regreet.service plasmalogin.service; do
    if systemctl is-enabled "$legacy" &>/dev/null; then
        log_info "Disabling legacy $legacy..."
        sudo systemctl disable --now "$legacy" 2>/dev/null || true
    fi
done

# Remove leftover SDDM theme trees from earlier experiments (SilentSDDM, eucalyptus-drop)
for theme in silent eucalyptus-drop; do
    if [[ -d "/usr/share/sddm/themes/$theme" ]]; then
        log_info "Removing legacy SDDM theme: $theme..."
        sudo rm -rf "/usr/share/sddm/themes/$theme"
    fi
done

svc_enable sddm

# ─── Stow compositor configs ───
stow_pkg hypr
stow_pkg rofi
stow_pkg cliphist

# ─── Deploy arche-legion binary (symlink so updates propagate) ───
mkdir -p "$HOME/.local/bin/arche"
ln -sf "$ARCHE/tools/bin/arche-legion" "$HOME/.local/bin/arche/arche-legion"
log_ok "Linked arche-legion"

log_ok "Hyprland setup done"
