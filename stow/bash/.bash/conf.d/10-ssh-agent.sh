#!/usr/bin/env bash
# Persistent ssh-agent — reuse across shells via ~/.ssh-agent-info.

_agent_file="$HOME/.ssh-agent-info"

if [[ -z "${SSH_AUTH_SOCK:-}" || ! -S "${SSH_AUTH_SOCK:-}" ]]; then
    [[ -f "$_agent_file" ]] && source "$_agent_file" >/dev/null

    if ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; then
        # Start agent, strip the `echo Agent pid ...` line, write env to file.
        ssh-agent -s | sed '/^echo /d' > "$_agent_file"
        source "$_agent_file" >/dev/null
        ssh-add -q "$HOME/.ssh/keys/id_ed25519_personal" "$HOME/.ssh/keys/leanscale" 2>/dev/null || true
    elif [[ -S "${SSH_AUTH_SOCK:-}" ]]; then
        :
    fi
fi

unset _agent_file
