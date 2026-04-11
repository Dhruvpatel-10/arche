#!/usr/bin/env bash
# Starship prompt — config rendered by theme.sh to ~/.config/starship/

if command -v starship &>/dev/null; then
    export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
    eval "$(starship init bash)"
fi
