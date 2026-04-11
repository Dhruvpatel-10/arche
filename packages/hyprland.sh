# Hyprland compositor stack — WM + portals + utilities.
# Used by: scripts/05-hyprland.sh

PACMAN_PKGS=(
    hyprland
    hyprlock
    hypridle
    hyprpicker
    hyprsunset
    uwsm                    # Hyprland session wrapper
    xdg-desktop-portal-hyprland

    # Login manager — SDDM with vendored SilentSDDM theme (see D013).
    # qt6-5compat       — Qt5Compat.GraphicalEffects shaders used by the theme
    # qt6-svg           — vector icons (sessions, power, language, etc.)
    # qt6-virtualkeyboard — required by the theme's QML imports even if VK is hidden
    # qt6-multimedia-ffmpeg — Multimedia QML module (for animated bg support;
    #                         imported unconditionally by Main.qml)
    sddm
    qt6-5compat
    qt6-svg
    qt6-virtualkeyboard
    qt6-multimedia-ffmpeg

    # Wayland utilities
    hyprpaper                # wallpaper daemon (static, hyprwm official)
    grim                     # screenshot capture
    slurp                    # region select
    satty                    # screenshot annotate
    wl-clipboard             # clipboard
    cliphist                 # clipboard history
    wev                      # input events debug
    brightnessctl             # backlight control (syshud backend)

    # App launcher — Spotlight-style (combi mode: apps + files + windows)
    rofi-wayland             # Rofi fork with native Wayland support

    # Theming / appearance
    qt5-wayland
    qt6-wayland
    hyprpolkitagent          # auth agent (native Hyprland, QT/QML)
)

AUR_PKGS=(
    syshud                   # OSD overlay (GTK4, auto-listens wireplumber+backlight)
)
