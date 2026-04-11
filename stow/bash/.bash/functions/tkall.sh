#!/usr/bin/env bash
# Kill all tmux sessions.
tkall() {
    local sess
    while IFS= read -r sess; do
        [[ -n $sess ]] && tmux kill-session -t "$sess"
    done < <(tmux ls 2>/dev/null | cut -d: -f1)
}
