# Reload kitty: SIGUSR1 → re-read config in place. Scoped to current user
# (stray PIDs from another user EPERM the kill, trip set -e).
if pids=$(pgrep -x -u "$USER" kitty 2>/dev/null); then
    # shellcheck disable=SC2086
    kill -SIGUSR1 $pids 2>/dev/null || true
    log_ok "Reloaded kitty"
fi
