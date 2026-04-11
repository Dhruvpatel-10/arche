#!/usr/bin/env bash
# ~/.bash_logout — runs on logout from a login shell.

# Clear screen on console logout to avoid leaving shell history visible.
if [[ "$SHLVL" -eq 1 && -x /usr/bin/clear_console ]]; then
    /usr/bin/clear_console -q
fi
