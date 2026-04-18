# Arche — prepend /usr/local/bin/arche to PATH for fish shells.
# Auto-linked by scripts/00-preflight.sh via link_system_all.
if not contains /usr/local/bin/arche $PATH
    set -gx PATH /usr/local/bin/arche $PATH
end
