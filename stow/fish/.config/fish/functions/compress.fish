function compress --description 'Create a high-compression tar archive'
    if contains -- $argv[1] -h --help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%scompress%s  Create a high-compression .tar.xz archive\n" $h $d
        printf "%s\n" $m"Compress one or more files or directories into a tar archive using xz."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  compress <path>\n"
        printf "  compress <path1> <path2> [path3 ...]\n"
        printf "\n"
        printf "%sOUTPUT%s\n" $k $d
        printf "  One input path   -> <name>.tar.xz\n"
        printf "  Multiple paths   -> archive.tar.xz\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  compress project\n"
        printf "  compress dir1 dir2 dir3\n"
        printf "\n"
        printf "%sNOTES%s\n" $k $d
        printf "  xz compresses better than gzip, but is slower.\n"
        printf "  Original files and directories are left unchanged.\n"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: compress <path> [path...]"
        echo "Try 'compress --help' for details."
        return 1
    end

    for path in $argv
        if not test -e $path
            echo "Path not found: $path"
            return 1
        end
    end

    if test (count $argv) -eq 1
        set -l src (string trim -r -c / -- $argv[1])
        set -l base (path basename -- $src)
        set -l archive "$base.tar.xz"
    else
        set -l archive archive.tar.xz
    end

    tar -cJf $archive $argv
    and echo "Created $archive"
end
