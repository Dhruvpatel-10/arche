#!/usr/bin/env bash
# Convert PNG to PDF.
pngtopdf() {
    if [[ $# -lt 1 || $# -gt 2 ]]; then
        echo "Usage: pngtopdf <input.png> [output.pdf]"
        return 1
    fi
    if [[ ! -f $1 ]]; then
        echo "Error: input file not found: $1"
        return 1
    fi
    local base="${1%.*}"
    local output="${2:-${base}.pdf}"
    magick -density 300 "$1" -quality 100 "$output"
}
