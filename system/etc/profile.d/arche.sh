# Arche — prepend /usr/local/bin/arche to PATH for POSIX shells.
# Auto-linked by scripts/00-preflight.sh via link_system_all.
case ":$PATH:" in
    *":/usr/local/bin/arche:"*) ;;
    *) PATH="/usr/local/bin/arche:$PATH"; export PATH ;;
esac
