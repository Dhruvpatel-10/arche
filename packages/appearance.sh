# Fonts, icons, cursors, GTK/Qt theming tools.
# Used by: scripts/11-appearance.sh

PACMAN_PKGS=(
    # Fonts
    ttf-ibm-plex              # IBM Plex Sans — UI sans-serif font
    ttf-meslo-nerd            # MesloLGS Nerd Font — primary mono (Menlo lineage)
    ttf-jetbrains-mono-nerd   # JetBrainsMono Nerd Font — fallback mono
    ttf-lato                  # Lato — Slack's bundled UI font; without it Slack falls to system sans and looks off
    noto-fonts                # Noto Sans/Serif — fallback for web pages and apps that name them
    noto-fonts-emoji          # Emoji fallback

    # Icons
    papirus-icon-theme        # Clean icon theme for GTK apps

    # GTK themes
    gnome-themes-extra        # provides real Adwaita-dark GTK3 theme files (not in gtk+3 default)

    # GTK theming tool (Hyprland stack — no KDE to handle GTK config)
    nwg-look                  # GTK3/4 theme configurator
)

AUR_PKGS=(
)
