#!/usr/bin/env bash
# 05-hyprland.sh — Hyprland compositor + Wayland utilities + SDDM greeter
source "$(dirname "$0")/lib.sh"

log_info "Setting up Hyprland..."
install_group "$ARCHE/packages/hyprland.sh"

# ─── SDDM Login Manager ───
# Deploy the vendored SilentSDDM theme. The source lives under vendor/sddm-silent/;
# we COPY rather than symlink because the `sddm` system user cannot traverse
# /home/<user> (mode 700) to follow symlinks back into the repo. SilentSDDM
# does not use the standard sddm theme.conf — it has its own config files
# under configs/ pointed to by metadata.desktop. We do not template the
# config (260+ keys); the user picks a variant by editing metadata.desktop.
# See docs/decisions.md D013.

theme_src="$ARCHE/vendor/sddm-silent"
theme_dst="/usr/share/sddm/themes/silent"

if [[ -d "$theme_src" ]]; then
    log_info "Installing sddm silent theme..."
    sudo install -d -m 755 "$theme_dst"
    # Wipe and re-mirror to stay idempotent when files are removed upstream.
    # .source is a provenance marker for humans, not needed at runtime.
    sudo find "$theme_dst" -mindepth 1 -delete
    (cd "$theme_src" && find . -mindepth 1 -not -name '.source' -print0) \
    | while IFS= read -r -d '' path; do
        rel="${path#./}"
        if [[ -d "$theme_src/$rel" ]]; then
            sudo install -d -m 755 "$theme_dst/$rel"
        else
            sudo install -m 644 "$theme_src/$rel" "$theme_dst/$rel"
        fi
    done
    log_ok "Theme installed at $theme_dst"
else
    log_warn "Vendored theme not found at $theme_src"
fi

# Clean up the previous eucalyptus-drop install if present (D013 retired it
# in favour of SilentSDDM). The theme tree on disk is not tracked by pacman
# so it has to be removed explicitly when migrating.
if [[ -d /usr/share/sddm/themes/eucalyptus-drop ]]; then
    log_info "Removing legacy eucalyptus-drop theme..."
    sudo rm -rf /usr/share/sddm/themes/eucalyptus-drop
    log_ok "Legacy theme removed"
fi

# Disable legacy greetd stack if present (migrated away — see D013).
for legacy in greetd.service greetd-regreet.service; do
    if systemctl is-enabled "$legacy" &>/dev/null; then
        log_info "Disabling legacy $legacy..."
        sudo systemctl disable --now "$legacy" 2>/dev/null || true
    fi
done

# Enable SDDM. sddm.conf.d/10-arche.conf is linked by link_system_all in 00.
svc_enable sddm

# Stow configs
stow_pkg hypr
stow_pkg rofi

# Deploy arche-legion binary (symlink so updates propagate)
mkdir -p "$HOME/.local/bin/arche"
ln -sf "$ARCHE/tools/bin/arche-legion" "$HOME/.local/bin/arche/arche-legion"
log_ok "Linked arche-legion"

log_ok "Hyprland setup done"
