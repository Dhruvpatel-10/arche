#!/usr/bin/env bash
# Create directory and cd into it.
mkcd() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: mkcd <directory>"
        return 1
    fi
    mkdir -p "$1" && cd "$1" || return 1
}
