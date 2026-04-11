# Shell packages — fish (primary) + prompt + terminal.
# Used by: scripts/06-shell.sh
#
# fisher is installed from upstream curl by 06-shell.sh — not from AUR.
# See docs/decisions.md D018 (reverses D016, restores D003).

PACMAN_PKGS=(
    fish                 # friendly interactive shell, default login shell
    atuin                # SQLite-backed fuzzy history + Ctrl-R
    starship             # cross-shell prompt
    kitty                # terminal emulator
    tmux                 # terminal multiplexer
)

AUR_PKGS=()
