# KDE Plasma desktop — no packages installed here.
# Used by: scripts/05-kde.sh
#
# Assumption: the `plasma` group + `sddm` are installed during Arch install
# (via archinstall or `pacstrap -K /mnt base linux linux-firmware plasma sddm ...`).
# The plasma group pulls in plasma-desktop, kwin, plasma-pa, plasma-nm,
# powerdevil, bluedevil, kscreen, breeze, breeze-gtk, kde-gtk-config,
# xdg-desktop-portal-kde, polkit-kde-agent, spectacle, kdialog, sddm-kcm,
# plasma-wayland-protocols, qt6-wayland, etc.
#
# scripts/05-kde.sh verifies this assumption and fails fast if KDE is missing.
# Add a package below only if it's arche-specific AND not pulled in by plasma.

PACMAN_PKGS=(
)

AUR_PKGS=(
)
