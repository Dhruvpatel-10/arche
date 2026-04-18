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

    # Docker
    # Rootless is preferred (no docker group = no root-equivalent access), but
    # Arch dropped `docker-rootless-extras` with Docker 29 — the upstream
    # `dockerd-rootless-setuptool.sh` is no longer packaged. Install the real
    # runtime deps (rootlesskit, slirp4netns) so a manual rootless setup works
    # if the user fetches the setuptool from upstream. Otherwise 08-apps.sh
    # falls back to system docker.
    docker
    docker-buildx
    docker-compose
    rootlesskit              # fake-root impl for rootless containers
    slirp4netns              # user-mode networking for rootless containers
)

AUR_PKGS=()
