#!/usr/bin/env bash
# Serve a directory over Tailscale network.
serve() {
    local port=9090
    local dir="${1:-.}"

    if ! command -v tailscale &>/dev/null; then
        echo "Error: tailscale not found"
        return 1
    fi

    local ts_ip
    ts_ip=$(tailscale ip -4 2>/dev/null)
    if [[ -z $ts_ip ]]; then
        echo "Error: tailscale not connected"
        return 1
    fi

    if ! command -v miniserve &>/dev/null; then
        echo "Error: miniserve not installed (paru -S miniserve)"
        return 1
    fi

    echo "Serving: $dir"
    echo "Access:  http://$ts_ip:$port"
    miniserve -p "$port" -i "$ts_ip" "$dir"
}
