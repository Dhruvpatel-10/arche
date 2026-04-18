#!/usr/bin/env bash
# 05-kde.sh — KDE Plasma desktop + Plasma Login Manager greeter
source "$(dirname "$0")/lib.sh"

log_info "Setting up KDE Plasma..."

# ─── Prereq: KDE must be installed at Arch install time ───
# packages/kde.sh is intentionally empty; the plasma group is assumed to have
# been installed via archinstall or pacstrap during the Arch install. The
# plasma group pulls in plasma-login-manager (the KDE-native display manager
# introduced in Plasma 6.6 as the replacement for SDDM — see D022).

missing=()
for pkg in plasma-desktop kwin plasma-login-manager; do
    pacman -Qq "$pkg" &>/dev/null || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    log_err "KDE prereqs missing: ${missing[*]}"
    log_info "Install them during Arch install (pacstrap -K /mnt ... plasma)"
    log_info "Or on a running system: sudo pacman -S plasma"
    exit 1
fi
log_ok "KDE prereqs present (plasma-desktop, kwin, plasma-login-manager)"

install_group "$ARCHE/packages/kde.sh"

# ─── Plasma Login Manager ───

# Disable legacy greeter stacks if present.
# - greetd + regreet: pre-KDE greeter (see D013, retired)
# - sddm: superseded by plasma-login-manager in Plasma 6.6 (see D022)
for legacy in greetd.service greetd-regreet.service sddm.service; do
    if systemctl is-enabled "$legacy" &>/dev/null; then
        log_info "Disabling legacy $legacy..."
        sudo systemctl disable --now "$legacy" 2>/dev/null || true
    fi
done

# Remove leftover SDDM theme trees if present (SilentSDDM from D013,
# eucalyptus-drop from an earlier attempt). plasma-login-manager does not
# use /usr/share/sddm/themes/.
for theme in silent eucalyptus-drop; do
    if [[ -d "/usr/share/sddm/themes/$theme" ]]; then
        log_info "Removing legacy SDDM theme: $theme..."
        sudo rm -rf "/usr/share/sddm/themes/$theme"
        log_ok "Legacy SDDM theme removed: $theme"
    fi
done

# Remove stale /etc/sddm.conf.d/10-arche.conf symlink if present
# (left over from pre-D022 installs; target no longer exists in the repo).
if [[ -L /etc/sddm.conf.d/10-arche.conf ]]; then
    log_info "Removing stale SDDM config symlink..."
    sudo rm -f /etc/sddm.conf.d/10-arche.conf
    sudo rmdir /etc/sddm.conf.d 2>/dev/null || true
    log_ok "Stale SDDM config removed"
fi

# Enable plasmalogin (Plasma Login Manager).
svc_enable plasmalogin

# ─── Stow Configs ───

# Stow KDE configs (keybinds, panel layout, etc.)
if [[ -d "$ARCHE/stow/kde" ]]; then
    stow_pkg kde
fi

# ─── arche-legion ───
# Deployed to /usr/local/bin/arche/ declaratively via system/usr/local/bin/arche/,
# auto-linked by link_system_all in 00-preflight.sh. Verify it's in place.
if [[ -x /usr/local/bin/arche/arche-legion ]]; then
    log_ok "arche-legion available at /usr/local/bin/arche/"
else
    log_warn "arche-legion not found — re-run 00-preflight.sh"
fi

# ─── Disable Baloo File Indexer ───
# Baloo indexes files inside encrypted vaults, defeating security.
# KDE search still works for apps/settings, just not file content.

if command -v balooctl6 &>/dev/null; then
    balooctl6 disable 2>/dev/null
    log_ok "Baloo file indexer disabled"
elif command -v balooctl &>/dev/null; then
    balooctl disable 2>/dev/null
    log_ok "Baloo file indexer disabled"
else
    log_warn "balooctl not found — skip Baloo disable"
fi

# ─── Fonts ───

if command -v kwriteconfig6 &>/dev/null; then
    log_info "Configuring KDE fonts..."
    kwriteconfig6 --file kdeglobals --group General --key font "IBM Plex Sans,10,-1,5,50,0,0,0,0,0"
    kwriteconfig6 --file kdeglobals --group General --key fixed "MesloLGS Nerd Font Mono,10,-1,5,50,0,0,0,0,0"
    kwriteconfig6 --file kdeglobals --group General --key smallestReadableFont "IBM Plex Sans,8,-1,5,50,0,0,0,0,0"
    kwriteconfig6 --file kdeglobals --group General --key toolBarFont "IBM Plex Sans,10,-1,5,50,0,0,0,0,0"
    kwriteconfig6 --file kdeglobals --group General --key menuFont "IBM Plex Sans,10,-1,5,50,0,0,0,0,0"
    kwriteconfig6 --file kdeglobals --group WM --key activeFont "IBM Plex Sans,10,-1,5,75,0,0,0,0,0"
    log_ok "KDE fonts configured"
else
    log_warn "kwriteconfig6 not found — skip font config"
fi

# ─── Icons & Cursor ───

if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file kdeglobals --group Icons --key Theme "Papirus-Dark"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "Bibata-Modern-Classic"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 24
    log_ok "Icons and cursor configured"
fi

# ─── Color Scheme ───
# Applied after theme.sh renders templates/kde/Ember.colors.tmpl

if [[ -f "$HOME/.local/share/color-schemes/Ember.colors" ]]; then
    if command -v plasma-apply-colorscheme &>/dev/null; then
        plasma-apply-colorscheme Ember 2>/dev/null && log_ok "Applied Ember color scheme"
    fi
elif [[ -f "$HOME/.config/kde/Ember.colors" ]]; then
    # Rendered but not yet copied — do it now
    mkdir -p "$HOME/.local/share/color-schemes"
    cp "$HOME/.config/kde/Ember.colors" "$HOME/.local/share/color-schemes/Ember.colors"
    if command -v plasma-apply-colorscheme &>/dev/null; then
        plasma-apply-colorscheme Ember 2>/dev/null && log_ok "Applied Ember color scheme"
    fi
else
    log_warn "Ember color scheme not found — run 'just theme apply' first"
fi

# ─── Behavior Defaults ───

if command -v kwriteconfig6 &>/dev/null; then
    # Single-click to open files (not double-click)
    kwriteconfig6 --file kdeglobals --group KDE --key SingleClick true
    # Dark color scheme hint for GTK apps
    kwriteconfig6 --file kdeglobals --group KDE --key ColorScheme "Ember"
    # Use Breeze as the Plasma style
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage "org.kde.breezedark.desktop"
    log_ok "KDE behavior defaults configured"
fi

log_ok "KDE Plasma setup done"
