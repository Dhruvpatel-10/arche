#!/usr/bin/env bash
# Create a timestamped backup of a file.
backup() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: backup <file>"
        return 1
    fi
    if [[ ! -e $1 ]]; then
        echo "File not found: $1"
        return 1
    fi
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    cp "$1" "$1.$ts.bak" && echo "Backed up to $1.$ts.bak"
}
