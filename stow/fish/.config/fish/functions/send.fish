function send --description "Send files/folders to a server from the arche-ssh inventory"
    # Thin wrapper so 'send' keeps working as a command while the real logic
    # lives in arche-send (bash), where launchd and arche-clip can also call it.
    if not command -q arche-send
        echo "send: arche-send is not on PATH — is the arche-cli package stowed?" >&2
        return 1
    end
    command arche-send $argv
end
