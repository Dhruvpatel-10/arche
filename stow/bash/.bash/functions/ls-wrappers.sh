#!/usr/bin/env bash
# eza wrappers — ls/lsa/lt/lta with fallbacks to plain ls.

ls() {
    if command -v eza &>/dev/null; then
        eza -lh --group-directories-first --icons=auto "$@"
    else
        command ls --color=auto "$@"
    fi
}

lsa() {
    if command -v eza &>/dev/null; then
        eza -lah --group-directories-first --icons=auto "$@"
    else
        command ls -lah --color=auto "$@"
    fi
}

lt() {
    if command -v eza &>/dev/null; then
        eza --tree --level=2 --long --icons --git "$@"
    else
        command ls -R "$@"
    fi
}

lta() {
    if command -v eza &>/dev/null; then
        eza --tree --level=2 --long --icons --git -a "$@"
    else
        command ls -Ra "$@"
    fi
}
