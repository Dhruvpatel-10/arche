#!/usr/bin/env bash
# 05-kde.sh — KDE Plasma desktop + SDDM greeter
source "$(dirname "$0")/lib.sh"

log_info "Setting up KDE Plasma..."

# ─── Prereq: KDE must be installed at Arch install time ───
# packages/kde.sh is intentionally empty; the plasma group + sddm are assumed
# to have been installed via archinstall or pacstrap during the Arch install.

missing=()
for pkg in plasma-desktop kwin sddm; do
    pacman -Qq "$pkg" &>/dev/null || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    log_err "KDE prereqs missing: ${missing[*]}"
    log_info "Install them during Arch install (pacstrap -K /mnt ... plasma sddm)"
    log_info "Or on a running system: sudo pacman -S plasma sddm"
    exit 1
fi
log_ok "KDE prereqs present (plasma-desktop, kwin, sddm)"

install_group "$ARCHE/packages/kde.sh"

# ─── SDDM Login Manager ───

# Disable legacy greetd stack if present (migrated away — see D013).
for legacy in greetd.service greetd-regreet.service; do
    if systemctl is-enabled "$legacy" &>/dev/null; then
        log_info "Disabling legacy $legacy..."
        sudo systemctl disable --now "$legacy" 2>/dev/null || true
    fi
done

# Remove vendored SilentSDDM theme if present (was used with Hyprland).
# KDE uses Breeze SDDM theme by default via sddm-kcm.
if [[ -d /usr/share/sddm/themes/silent ]]; then
    log_info "Removing legacy SilentSDDM theme..."
    sudo rm -rf /usr/share/sddm/themes/silent
    log_ok "Legacy SilentSDDM theme removed"
fi

# Clean up legacy eucalyptus-drop if present.
if [[ -d /usr/share/sddm/themes/eucalyptus-drop ]]; then
    log_info "Removing legacy eucalyptus-drop theme..."
    sudo rm -rf /usr/share/sddm/themes/eucalyptus-drop
    log_ok "Legacy theme removed"
fi

# Enable SDDM.
svc_enable sddm

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
