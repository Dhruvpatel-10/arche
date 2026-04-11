#!/usr/bin/env bash
# Compress directory to tar.gz.
compress() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: compress <directory>"
        return 1
    fi
    local dir="${1%/}"
    tar -czf "${dir}.tar.gz" "$dir"
}
