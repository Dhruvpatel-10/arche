#!/usr/bin/env bash
# Extract any common archive format.
extract() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    if [[ ! -f $1 ]]; then
        echo "File not found: $1"
        return 1
    fi

    case "$1" in
        *.tar.gz|*.tgz)     tar -xzf "$1" ;;
        *.tar.bz2|*.tbz2)   tar -xjf "$1" ;;
        *.tar.xz|*.txz)     tar -xJf "$1" ;;
        *.tar.zst)          tar --zstd -xf "$1" ;;
        *.tar)              tar -xf "$1" ;;
        *.zip)              unzip "$1" ;;
        *.7z)               7z x "$1" ;;
        *.rar)              unrar x "$1" ;;
        *.gz)               gunzip "$1" ;;
        *.bz2)              bunzip2 "$1" ;;
        *.xz)               unxz "$1" ;;
        *.zst)              unzstd "$1" ;;
        *)
            echo "Unknown archive format: $1"
            return 1
            ;;
    esac
}
