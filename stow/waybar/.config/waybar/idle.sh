#!/usr/bin/env bash
# Waybar custom module: show icon when idle lock is disabled.

if pgrep -x hypridle >/dev/null; then
    echo '{"text": "", "class": "enabled"}'
else
    echo '{"text": "󱫖", "tooltip": "Idle lock disabled", "class": "disabled"}'
fi
