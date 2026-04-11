#!/usr/bin/env bash
# Open file with default application.
open() {
    xdg-open "$@" >/dev/null 2>&1 &
    disown
}
