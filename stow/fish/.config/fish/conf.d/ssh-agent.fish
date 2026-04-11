# Start ssh-agent if not already running

if not set -q SSH_AUTH_SOCK; or not test -S "$SSH_AUTH_SOCK"
    set -l agent_file $HOME/.ssh-agent-info.fish

    if test -f $agent_file
        source $agent_file
    end

    if not pgrep -u $USER ssh-agent >/dev/null 2>&1
        # Start agent and write env vars to file
        ssh-agent -c | sed 's/ *echo Agent pid [0-9]*;//' >$agent_file
        source $agent_file
        ssh-add -q ~/.ssh/keys/id_ed25519_personal ~/.ssh/keys/leanscale 2>/dev/null
    end
end
