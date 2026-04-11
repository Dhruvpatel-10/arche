#!/usr/bin/env bash
# fnm — Fast Node Manager

_fnm_path="$HOME/.local/share/fnm"

if [[ -d "$_fnm_path" ]]; then
    case ":$PATH:" in
        *":$_fnm_path:"*) ;;
        *) PATH="$_fnm_path:$PATH" ;;
    esac
    export PATH
    eval "$(fnm env --use-on-cd --shell bash)"
fi

unset _fnm_path
