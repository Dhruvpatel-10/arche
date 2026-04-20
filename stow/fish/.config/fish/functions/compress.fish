function compress --description 'Create a compressed tar archive (xz/zstd/gzip/bzip2)'
    argparse h/help f/format= l/level= o/output= -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%scompress%s  Pack files/dirs into a compressed tar archive\n" $h $d
        printf "%s\n" $m"Runs tar, then pipes the stream through xz (default), zstd, gzip, or bzip2."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  compress [options] <path> [path...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -f, --format FMT   xz (default) | zstd | gzip | bzip2\n"
        printf "  -l, --level  N     compression level 1-9 (format's default if unset)\n"
        printf "  -o, --output FILE  archive path (overrides the auto-generated name)\n"
        printf "  -h, --help         show this help\n"
        printf "\n"
        printf "%sFORMATS%s\n" $k $d
        printf "  xz     .tar.xz   best ratio, slow          %s(default)%s\n" $m $d
        printf "  zstd   .tar.zst  fast, near-xz ratio\n"
        printf "  gzip   .tar.gz   fast, maximum compatibility\n"
        printf "  bzip2  .tar.bz2  legacy, slow, decent ratio\n"
        printf "\n"
        printf "%sOUTPUT NAME%s\n" $k $d
        printf "  One path   -> <name>.tar.<ext>\n"
        printf "  Many paths -> archive.tar.<ext>\n"
        printf "  --output overrides both. If it lacks the .tar.<ext> suffix (matching\n"
        printf "  the chosen format) it is appended, so -o backup + xz -> backup.tar.xz.\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  compress project                     %s# project.tar.xz%s\n" $m $d
        printf "  compress -f zstd project             %s# project.tar.zst%s\n" $m $d
        printf "  compress -f gzip -l 9 site           %s# site.tar.gz, max gzip%s\n" $m $d
        printf "  compress -o backup dir1 dir2         %s# backup.tar.xz (ext appended)%s\n" $m $d
        printf "  compress -f zstd -o /tmp/out work    %s# /tmp/out.tar.zst%s\n" $m $d
        printf "\n"
        printf "%sNOTES%s\n" $k $d
        printf "  Originals are left untouched. Use 'extract' to unpack.\n"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: compress [options] <path> [path...]"
        echo "Try 'compress --help' for details."
        return 1
    end

    for path in $argv
        if not test -e $path
            echo "Path not found: $path"
            return 1
        end
    end

    set -l format xz
    set -q _flag_format; and set format $_flag_format

    set -l ext
    set -l tar_flag
    switch $format
        case xz
            set ext tar.xz
            set tar_flag -J
        case zstd zst
            set ext tar.zst
            set tar_flag --zstd
        case gzip gz
            set ext tar.gz
            set tar_flag -z
        case bzip2 bz2
            set ext tar.bz2
            set tar_flag -j
        case '*'
            echo "Unknown format: $format (use xz, zstd, gzip, or bzip2)"
            return 1
    end

    set -l archive
    if set -q _flag_output
        set archive $_flag_output
        if not string match -q -- "*.$ext" $archive
            set archive $archive.$ext
        end
    else if test (count $argv) -eq 1
        set -l src (string trim -r -c / -- $argv[1])
        set archive (path basename -- $src).$ext
    else
        set archive archive.$ext
    end

    if set -q _flag_level
        if not string match -qr '^[1-9]$' -- $_flag_level
            echo "Invalid level: $_flag_level (expected 1-9)"
            return 1
        end
        switch $format
            case xz
                set -x XZ_OPT -$_flag_level
            case zstd zst
                set -x ZSTD_CLEVEL $_flag_level
            case gzip gz
                set -x GZIP -$_flag_level
            case bzip2 bz2
                set -x BZIP2 -$_flag_level
        end
    end

    tar --create $tar_flag --file=$archive -- $argv
    and echo "Created $archive ($format)"
end
