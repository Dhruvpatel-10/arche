function backup --description 'Create timestamped backups of file(s) (.<stamp>.bak)'
    argparse h/help 'd/dest=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sbackup%s  Copy file(s) to <name>.<timestamp>.bak\n" $h $d
        printf "%s\n" $m"Timestamp is YYYYMMDD-HHMMSS and shared across all files in one call."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  backup [options] <file> [file...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -d, --dest DIR   write backups into DIR (created if missing)\n"
        printf "  -h, --help       show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  backup config.yaml                 %s# config.yaml.<stamp>.bak%s\n" $m $d
        printf "  backup -d ~/backups config.yaml    %s# ~/backups/config.yaml.<stamp>.bak%s\n" $m $d
        printf "  backup a.conf b.conf               %s# both share the same timestamp%s\n" $m $d
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: backup [options] <file> [file...]"
        echo "Try 'backup --help' for details."
        return 1
    end

    for f in $argv
        if not test -e $f
            echo "File not found: $f"
            return 1
        end
    end

    set -l dest
    if set -q _flag_dest
        set dest (string trim -r -c / -- $_flag_dest)
        mkdir -p $dest
        or return 1
    end

    set -l stamp (date +%Y%m%d-%H%M%S)

    for f in $argv
        set -l out
        if test -n "$dest"
            set out $dest/(path basename -- $f).$stamp.bak
        else
            set out $f.$stamp.bak
        end
        cp -r -- $f $out
        or return 1
        echo "Backed up $f -> $out"
    end
end
