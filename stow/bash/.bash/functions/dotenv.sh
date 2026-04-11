#!/usr/bin/env bash
# Load .env file into shell environment.
dotenv() {
    local envfile="${1:-.env}"
    if [[ ! -f $envfile ]]; then
        echo "File not found: $envfile"
        return 1
    fi
    local line key val
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line =~ ^[[:space:]]*# ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        [[ -n $key && $key != "$line" ]] && export "$key=$val"
    done < "$envfile"
    echo "Loaded $envfile"
}
