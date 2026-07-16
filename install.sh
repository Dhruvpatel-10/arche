#!/usr/bin/env bash
# install.sh — the one-line installer for arche. Works on Arch Linux and macOS.
#
#   Arch:   curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh | bash
#   macOS:  bash <(curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh)
#
# It figures out your system, downloads arche to the right place, and starts the
# installer. On Arch it lives in /opt/arche so every user on the machine shares
# one copy, with a ~/arche shortcut. On macOS it lives in your home directory.
#
# The download is permanent: your config files link back into it, so keep it.
set -eu

ARCHE_REPO="${ARCHE_REPO:-https://github.com/Dhruvpatel-10/arche.git}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

os="$(uname -s)"
case "$os" in
    Linux)
        [ -f /etc/arch-release ] || err "This installer needs Arch Linux (or macOS)."
        command -v git  >/dev/null 2>&1 || err "Please install git first:  sudo pacman -S git"
        command -v sudo >/dev/null 2>&1 || err "Please install sudo first."
        ping -c 1 -W 3 archlinux.org >/dev/null 2>&1 || err "No internet connection."

        DIR="${ARCHE_DIR:-/opt/arche}"
        GROUP="users"
        if [ -d "$DIR/.git" ]; then
            info "arche is already at $DIR, updating it"
            git -C "$DIR" pull --ff-only || err "Update failed. Fix it by hand, then re-run."
        else
            [ -e "$DIR" ] && err "$DIR exists but is not an arche checkout. Remove it first."
            info "Downloading arche to $DIR (this needs sudo for /opt)"
            sudo install -d -m 2775 -o "$USER" -g "$GROUP" "$DIR"
            git clone "$ARCHE_REPO" "$DIR"
        fi
        # Let every user in the shared group read and write the tree.
        sudo chown -R "$USER:$GROUP" "$DIR"
        sudo find "$DIR" -type d -exec chmod 2775 {} \;
        ok "arche is ready at $DIR"

        # ~/arche shortcut.
        if [ -L "$HOME/arche" ]; then :
        elif [ -e "$HOME/arche" ]; then err "$HOME/arche exists and is not a link. Move it aside."
        else ln -s "$DIR" "$HOME/arche"; ok "Made the shortcut ~/arche"
        fi
        ;;
    Darwin)
        [ "$(uname -m)" = "arm64" ] || err "The macOS setup is for Apple Silicon (arm64)."
        command -v git >/dev/null 2>&1 || err "Please install the developer tools first:  xcode-select --install"

        DIR="${ARCHE_DIR:-$HOME/arche}"
        if [ -d "$DIR/.git" ]; then
            info "arche is already at $DIR, updating it"
            git -C "$DIR" pull --ff-only || err "Update failed. Fix it by hand, then re-run."
        elif [ -e "$DIR" ]; then
            err "$DIR exists but is not an arche checkout. Remove it, or set ARCHE_DIR=/path."
        else
            info "Downloading arche to $DIR"
            git clone "$ARCHE_REPO" "$DIR"
        fi
        ok "arche is ready at $DIR"
        ;;
    *)
        err "Unsupported system: $os. arche supports Arch Linux and macOS."
        ;;
esac

info "Starting the arche installer"
exec bash "$DIR/bootstrap.sh" "$@"
