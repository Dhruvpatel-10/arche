# Desktop applications — browsers, editors, tools.
# Used by: scripts/08-apps.sh

PACMAN_PKGS=(
    # Editor
    neovim

    # Browsers
    vivaldi

    # File management
    dolphin                  # KDE file manager
    syncthing

    # Media
    mpv
    imagemagick              # CLI image manipulation
    ffmpegthumbs             # Dolphin video thumbnail plugin
    kdenlive                 # video editor (KDE native)

    # Recording
    obs-studio                   # screen recording / streaming
    v4l2loopback-dkms            # virtual camera support

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
    okular                   # PDF/EPUB viewer + annotation (KDE native)
    gwenview                 # image viewer (KDE native)
    kdeconnect               # phone integration (clipboard, files, notifications)

    # Bluetooth
    bluez
    bluez-utils

    # Docker (rootless — no docker group needed)
    docker
    docker-rootless-extras
    docker-buildx
    docker-compose
)

AUR_PKGS=()
