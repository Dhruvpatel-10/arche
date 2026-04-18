# Fonts, icons, cursors, GTK/Qt theming tools.
# Used by: scripts/10-appearance.sh

PACMAN_PKGS=(
    # Fonts
    ttf-ibm-plex              # IBM Plex Sans — UI sans-serif font
    ttf-meslo-nerd            # MesloLGS Nerd Font — primary mono (Menlo lineage)
    ttf-jetbrains-mono-nerd   # JetBrainsMono Nerd Font — fallback mono
    noto-fonts-emoji          # Emoji fallback

    # Icons
    papirus-icon-theme        # Clean icon theme for GTK apps

    # GTK/Qt integration handled by kde-gtk-config (in kde.sh)
)

AUR_PKGS=(
)
