# Shell packages — bash (primary) + prompt + terminal.
# Used by: scripts/06-shell.sh
#
# ble.sh and bash-preexec are vendored under /opt/arche/vendor/ — not packages.
# carapace is a vendored binary under tools/bin/carapace — not a package.
# See docs/decisions.md D016.

PACMAN_PKGS=(
    bash                 # GNU bash, default login shell
    bash-completion      # system-wide bash completion fallback for anything carapace doesn't cover
    atuin                # SQLite-backed fuzzy history + encrypted sync (used in offline mode)
    starship             # cross-shell prompt
    kitty                # terminal emulator
    tmux                 # terminal multiplexer
)

AUR_PKGS=()
