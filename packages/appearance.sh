# Fonts, icons, cursors, GTK/Qt theming tools.
# Used by: scripts/11-appearance.sh

PACMAN_PKGS=(
    # Fonts
    ttf-ibm-plex              # IBM Plex Sans — UI sans-serif font
    ttf-meslo-nerd            # MesloLGS Nerd Font — primary mono (Menlo lineage)
    ttf-jetbrains-mono-nerd   # JetBrainsMono Nerd Font — fallback mono
    noto-fonts-emoji          # Emoji fallback

    # Icons
    papirus-icon-theme        # Clean icon theme for GTK apps

    # GTK theming tool (Hyprland stack — no KDE to handle GTK config)
    nwg-look                  # GTK3/4 theme configurator
)

AUR_PKGS=(
)
