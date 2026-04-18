# KDE Plasma desktop — no packages installed here.
# Used by: scripts/05-kde.sh
#
# Assumption: the `plasma` group is installed during Arch install
# (via archinstall or `pacstrap -K /mnt base linux linux-firmware plasma ...`).
# As of Plasma 6.6 the plasma group pulls in plasma-login-manager (the
# KDE-native replacement for SDDM — see D022), alongside plasma-desktop, kwin,
# plasma-pa, plasma-nm, powerdevil, bluedevil, kscreen, breeze, breeze-gtk,
# kde-gtk-config, xdg-desktop-portal-kde, polkit-kde-agent, spectacle, kdialog,
# plasma-wayland-protocols, qt6-wayland, etc.
#
# scripts/05-kde.sh verifies this assumption and fails fast if KDE is missing.
# Add a package below only if it's arche-specific AND not pulled in by plasma.

PACMAN_PKGS=(
)

AUR_PKGS=(
)
