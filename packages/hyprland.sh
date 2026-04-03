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
    greetd                  # minimal login daemon

    # Wayland utilities
    swww                     # wallpaper daemon (animated transitions)
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
