#!/usr/bin/env bash
# Convert image to compressed lossless PNG.
img2png() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: img2png <input>"
        return 1
    fi
    local base="${1%.*}"
    magick "$1" -strip \
        -define png:compression-filter=5 \
        -define png:compression-level=9 \
        -define png:compression-strategy=1 \
        -define png:exclude-chunk=all \
        "${base}.png"
}
