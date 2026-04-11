#!/usr/bin/env bash
# Convert image to high-quality JPG.
img2jpg() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: img2jpg <input>"
        return 1
    fi
    local base="${1%.*}"
    magick "$1" -quality 95 -strip "${base}.jpg"
}

# Convert image to small JPG (1080px max).
img2jpg-small() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: img2jpg-small <input>"
        return 1
    fi
    local base="${1%.*}"
    magick "$1" -resize '1080x>' -quality 95 -strip "${base}.jpg"
}
