function port --description 'Show process(es) listening on a given port'
    argparse h/help u/udp -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sport%s  Show process listening on a specific port (exact match)\n" $h $d
        printf "%s\n" $m"Wraps ss(8) with a 'sport = :N' filter — avoids substring false matches."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  port [options] <port>\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -u, --udp   include UDP sockets (default: TCP only)\n"
        printf "  -h, --help  show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  port 8080           %s# TCP listener on :8080%s\n" $m $d
        printf "  port -u 53          %s# include UDP (e.g. DNS)%s\n" $m $d
        return 0
    end

    if test (count $argv) -ne 1
        echo "Usage: port [options] <port>"
        return 1
    end

    if not string match -qr '^[0-9]+$' -- $argv[1]
        echo "Invalid port: $argv[1]"
        return 1
    end

    set -l flags -tlnp
    set -q _flag_udp; and set flags -tulnp

    ss $flags "sport = :$argv[1]"
end
