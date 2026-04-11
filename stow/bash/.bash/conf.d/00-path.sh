#!/usr/bin/env bash
# PATH and environment exports — loaded first by .bashrc
# See docs/decisions.md D014 (/opt/arche shared repo) and D016 (fish→bash).

export ARCHE=/opt/arche

export BUN_INSTALL="$HOME/.bun"
export CUDA_PATH=/opt/cuda
export PNPM_HOME="$HOME/.local/share/pnpm"

# Idempotent PATH prepender — only adds if dir exists and not already in PATH.
# Mirrors fish's fish_add_path.
_bash_add_path() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
    esac
    PATH="$dir:$PATH"
}

_bash_add_path "$HOME/.local/bin"
_bash_add_path "$HOME/.local/bin/arche"
_bash_add_path "$HOME/.cargo/bin"
_bash_add_path "$HOME/go/bin"
_bash_add_path "$HOME/.cache/.bun/bin"
_bash_add_path "$BUN_INSTALL/bin"
_bash_add_path "$PNPM_HOME"
_bash_add_path /opt/cuda/bin

export PATH
unset -f _bash_add_path
