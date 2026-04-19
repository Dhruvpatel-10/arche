# Quickshell panel stack — bar, control-center, notifications, OSD.
# Used by: scripts/07-panel.sh
#
# The QML source lives at /opt/arche/shell/ (versioned with the rest of the
# repo) — 07-panel.sh symlinks it into ~/.config/quickshell/. See D029.

PACMAN_PKGS=(
    quickshell               # QML-based Wayland shell (layer-shell)
    networkmanager           # nmcli — Net service backend
    # brightnessctl, bluez, bluez-utils are already declared elsewhere
)

AUR_PKGS=()
