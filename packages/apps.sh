# Desktop applications — browsers, editors, tools.
# Used by: scripts/10-apps.sh

PACMAN_PKGS=(
    # Editor
    neovim

    # Browsers
    vivaldi

    # File management
    yazi                     # TUI file manager
    syncthing

    # Media
    mpv
    imv                      # image viewer
    imagemagick
    ffmpegthumbnailer

    # Utilities
    fastfetch
    glow                     # markdown viewer
    aria2                    # download manager
    tldr
    github-cli
    plocate                  # locate
    tree-sitter-cli

    # Desktop apps
    qbittorrent
    zathura                  # PDF viewer (minimal, vim-style)
    zathura-pdf-mupdf        # PDF/EPUB backend (fast MuPDF renderer)

    # Bluetooth
    bluez
    bluez-utils

    # Docker (rootless — no docker group needed)
    docker
    docker-rootless-extras
    docker-buildx
    docker-compose
)

AUR_PKGS=(
    ripdrag                  # drag-and-drop from TUI (GTK4, Wayland-native)
)
