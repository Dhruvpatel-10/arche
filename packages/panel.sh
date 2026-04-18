# Quickshell panel stack — bar, control-center, notifications, OSD.
# Used by: scripts/07-panel.sh
#
# The shell itself (QML source) lives in the external arche-shell repo
# (https://github.com/Dhruvpatel-10/quickshell) — 07-panel.sh clones it and
# symlinks it into ~/.config/quickshell/. See D023.

PACMAN_PKGS=(
    quickshell               # QML-based Wayland shell (layer-shell)
    networkmanager           # nmcli — Net service backend
    # brightnessctl, bluez, bluez-utils are already declared elsewhere
)

AUR_PKGS=()
