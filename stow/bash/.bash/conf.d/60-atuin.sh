#!/usr/bin/env bash
# Atuin — SQLite-backed fuzzy history + Ctrl-R.
# Requires bash-preexec to already be sourced (done in .bashrc before this).
# --disable-up-arrow keeps Up walking the local history naturally; Ctrl-R opens Atuin.

if command -v atuin &>/dev/null; then
    eval "$(atuin init bash --disable-up-arrow)"
fi
