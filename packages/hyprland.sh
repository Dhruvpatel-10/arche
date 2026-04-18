# Hyprland compositor stack — WM + portals + utilities + login manager.
# Used by: scripts/05-hyprland.sh

PACMAN_PKGS=(
    # Compositor + session
    hyprland
    hyprlock                 # screen locker
    hypridle                 # idle daemon
    hyprpicker               # color picker
    hyprsunset               # night-light
    hyprpolkitagent          # native polkit auth agent (Qt/QML)
    uwsm                     # Hyprland session wrapper (systemd-managed)
    xdg-desktop-portal-hyprland

    # Login manager (default Breeze theme — see D023)
    sddm
    qt6-svg                  # SVG assets used by default SDDM themes
    qt5-wayland              # Qt5 Wayland plugin for session apps
    qt6-wayland              # Qt6 Wayland plugin

    # Wallpaper
    awww                     # successor to swww — smooth transitions, clean IPC (D026)

    # Screenshot / screen-share / clipboard
    grim                     # screenshot capture
    slurp                    # region select
    satty                    # screenshot annotate
    cliphist                 # clipboard history (wl-clipboard is in base.sh)

    # Input / backlight / debug
    brightnessctl            # backlight control
    wev                      # input-events debug

    # App launcher
    rofi-wayland             # Spotlight-style launcher (combi mode)

    # Screen-share source picker runtime deps (arche-share-picker is a tools/ binary — D027)
    gtk4-layer-shell         # GTK4 layer-shell binding used by arche-share-picker
)

AUR_PKGS=()
