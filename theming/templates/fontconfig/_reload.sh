# Reload hook: rebuild fontconfig cache so apps pick up new aliases.
# Sourced by theming/engine.sh after fonts.conf is rendered.
if command -v fc-cache &>/dev/null; then
    fc-cache -f &>/dev/null && log_ok "fontconfig cache rebuilt"
fi
