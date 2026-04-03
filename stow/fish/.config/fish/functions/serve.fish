function serve --description 'Serve a directory over Tailscale network'
    set -l port 9090
    set -l dir .

    if test (count $argv) -ge 1
        set dir $argv[1]
    end

    if not command -q tailscale
        echo "Error: tailscale not found"
        return 1
    end

    set -l ts_ip (tailscale ip -4 2>/dev/null)
    if test -z "$ts_ip"
        echo "Error: tailscale not connected"
        return 1
    end

    if not command -q miniserve
        echo "Error: miniserve not installed (paru -S miniserve)"
        return 1
    end

    echo "Serving: $dir"
    echo "Access:  http://$ts_ip:$port"
    miniserve -p $port -i $ts_ip $dir
end
