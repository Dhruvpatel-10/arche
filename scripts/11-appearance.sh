#!/usr/bin/env bash
# 11-appearance.sh — fonts, icons, cursors, GTK/Qt theming
source "$(dirname "$0")/lib.sh"

log_info "Setting up appearance..."
install_group "$ARCHE/packages/appearance.sh"

# Rebuild font cache after installing new fonts
if command -v fc-cache &>/dev/null; then
    log_info "Rebuilding font cache..."
    fc-cache -f
    log_ok "Font cache updated"
fi

# Set Loupe as default image viewer (libadwaita, matches our GTK theming)
if command -v xdg-mime &>/dev/null && [[ -f /usr/share/applications/org.gnome.Loupe.desktop ]]; then
    xdg-mime default org.gnome.Loupe.desktop \
        image/png image/jpeg image/webp image/gif image/bmp image/tiff image/svg+xml image/avif image/heif
    log_ok "Loupe set as default image viewer"
fi

# Set Papers as default PDF/EPUB viewer (libadwaita, matches our GTK theming)
if command -v xdg-mime &>/dev/null && [[ -f /usr/share/applications/org.gnome.Papers.desktop ]]; then
    xdg-mime default org.gnome.Papers.desktop \
        application/pdf application/x-pdf application/epub+zip \
        application/x-cbr application/x-cbz image/vnd.djvu
    log_ok "Papers set as default document viewer"
fi

# Papers is a GTK4/libadwaita app, so it picks up gtk-4.0/gtk.css. These
# defaults make the first-open document layout match the themed reader chrome.
if command -v gsettings &>/dev/null && gsettings list-schemas | grep -qx 'org.gnome.Papers.Default'; then
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}${XDG_RUNTIME_DIR:-}" ]]; then
        gsettings set org.gnome.Papers.Default show-sidebar true 2>/dev/null || true
        gsettings set org.gnome.Papers.Default sidebar-page 'thumbnails' 2>/dev/null || true
        gsettings set org.gnome.Papers.Default sizing-mode 'automatic' 2>/dev/null || true
        gsettings set org.gnome.Papers.Default continuous true 2>/dev/null || true
        log_ok "Papers reader defaults applied"
    fi
fi

# Render appearance templates — propagates palette to GTK3/4 + Electron.
# theme_render also calls gsettings to flip libadwaita + xdg-portal into dark mode.
theme_render gtk-3.0 gtk-4.0 electron-flags

log_ok "Appearance setup done"
