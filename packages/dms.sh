# dms.sh — DankMaterialShell (Quickshell-based desktop shell)
# Replaces the hand-rolled /opt/arche/shell/ panel as the bar + control
# center + notifications + OSD + launcher layer. See D032.
#
# dms-shell        — the shell (Quickshell QML frontend + Go backend `dms`)
# dms-shell-hyprland — Hyprland-specific meta (pulls compositor glue)
# Both ship in the official `extra` repo — no AUR, no curl-pipe.

PACMAN_PKGS=(
    dms-shell                # pulls quickshell + dgop + accountsservice + dms-shell-compositor
    dms-shell-hyprland
    networkmanager           # runtime network backend dms talks to over D-Bus (not a dms dep)
)

AUR_PKGS=()
