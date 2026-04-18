# Development runtimes — languages and toolchains.
# Used by: scripts/07-runtimes.sh
# Note: fnm, bun, rustup are installed via their own install scripts, not pacman.

PACMAN_PKGS=(
    rust                     # Rust via pacman (or use rustup manually)
    go                       # Go toolchain
    cmake
    clang
    gdb
)

AUR_PKGS=(
)
