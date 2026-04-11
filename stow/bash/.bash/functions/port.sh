#!/usr/bin/env bash
# Show what is listening on a given port.
port() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: port <port_number>"
        return 1
    fi
    ss -tlnp | grep -- "$1"
}
