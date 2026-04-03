# Base system packages — core tools expected on every install.
# Used by: scripts/01-base.sh

PACMAN_PKGS=(
    # Core utilities
    base-devel
    git
    stow
    just
    curl
    wget
    unzip
    p7zip

    # Modern CLI replacements
    eza           # ls
    bat           # cat
    ripgrep       # grep
    fd            # find
    fzf           # fuzzy finder
    zoxide        # cd
    dust          # du
    btop          # top
    nvtop         # GPU monitor
    jq            # JSON
    yq            # YAML
    tealdeer      # tldr — simplified man pages
    gum           # CLI formatting (prompts, spinners, etc.)
    lazygit       # TUI git client
    lazydocker    # TUI docker client

    # System
    linux-headers     # kernel headers (required for DKMS modules like nvidia-open)
    man-db
    man-pages
    amd-ucode         # AMD CPU microcode (Spectre/Meltdown patches)
    reflector         # mirror ranking
    snapper           # btrfs snapshots
    shellcheck        # shell script linter (used by tests/)
)

AUR_PKGS=(
)
