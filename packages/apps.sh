# Desktop applications — browsers, editors, tools.
# Used by: scripts/09-apps.sh

PACMAN_PKGS=(
    # Editor
    neovim

    # Browsers
    vivaldi

    # File management
    nautilus                 # GNOME file manager
    syncthing

    # Media
    mpv
    imagemagick              # CLI image manipulation
    papers                   # GTK4/libadwaita PDF/EPUB/DjVu viewer (modern Evince successor)
    loupe                    # GTK4/libadwaita image viewer
    kdenlive                 # video editor

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
    kdeconnect               # phone integration
    kio-extras               # KIO workers (tags, recentdocuments, mtp, …) — kdeconnectd resolves clipboard URLs through KIO
    gvfs-mtp                 # MTP backend for GIO — Nautilus/file managers see Android phones in File Transfer mode
    gvfs-gphoto2             # PTP backend — phones in Camera/PTP mode and actual cameras

    # Bluetooth
    bluez
    bluez-utils
    bluetui                  # TUI for pairing/managing bluetooth (Super+Ctrl+B)

    # Network TUI
    impala                   # TUI for WiFi (Super+Ctrl+W)

    # Docker
    # Rootless is preferred (no docker group = no root-equivalent access), but
    # Arch dropped `docker-rootless-extras` with Docker 29 — the upstream
    # `dockerd-rootless-setuptool.sh` is no longer packaged. Install the real
    # runtime deps (rootlesskit, slirp4netns) so a manual rootless setup works
    # if the user fetches the setuptool from upstream. Otherwise 09-apps.sh
    # falls back to system docker.
    docker
    docker-buildx
    docker-compose
    rootlesskit              # fake-root impl for rootless containers
    slirp4netns              # user-mode networking for rootless containers
)

AUR_PKGS=()
