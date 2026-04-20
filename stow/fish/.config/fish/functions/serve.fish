function serve --description 'Serve a directory on your tailnet via miniserve'
    argparse h/help 'p/port=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sserve%s  HTTP-serve a directory, reachable only from your tailnet\n" $h $d
        printf "%s\n" $m"Binds miniserve to this host's Tailscale IPv4 — not exposed to LAN/WAN."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  serve [options] [DIR]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -p, --port N   listen port (default 9090)\n"
        printf "  -h, --help     show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  serve                          %s# cwd on :9090%s\n" $m $d
        printf "  serve ~/Downloads              %s# downloads on :9090%s\n" $m $d
        printf "  serve -p 8000 ~/share          %s# custom port%s\n" $m $d
        return 0
    end

    set -l port 9090
    if set -q _flag_port
        if not string match -qr '^[0-9]+$' -- $_flag_port
            echo "Invalid port: $_flag_port"
            return 1
        end
        set port $_flag_port
    end

    set -l dir .
    test (count $argv) -ge 1; and set dir $argv[1]

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
