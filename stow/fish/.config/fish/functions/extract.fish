function extract --description 'Unpack common archive formats'
    if contains -- $argv[1] -h --help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sextract%s     Unpack common archive formats\n" $h $d
        printf "%s\n" $m"Extracts archives into the current directory based on file extension."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  extract <archive>\n"
        printf "\n"
        printf "%sSUPPORTED FORMATS%s\n" $k $d
        printf "  .tar            .tar.gz / .tgz     .tar.bz2 / .tbz2\n"
        printf "  .tar.xz / .txz  .tar.zst           .tar.lz4\n"
        printf "  .zip            .7z                .rar\n"
        printf "  .gz             .bz2               .xz\n"
        printf "  .zst            .lz4\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  extract backup.tar.xz\n"
        printf "  extract photos.zip\n"
        printf "\n"
        printf "%sNOTES%s\n" $k $d
        printf "  Archives are extracted into the current directory.\n"
        printf "  Single-file formats like .gz or .xz are decompressed in place.\n"
        return 0
    end

    if test (count $argv) -ne 1
        echo "Usage: extract <archive>"
        echo "Try 'extract --help' for details."
        return 1
    end

    if not test -f $argv[1]
        echo "File not found: $argv[1]"
        return 1
    end

    switch $argv[1]
        case '*.tar.gz' '*.tgz'
            tar -xzf $argv[1]
        case '*.tar.bz2' '*.tbz2'
            tar -xjf $argv[1]
        case '*.tar.xz' '*.txz'
            tar -xJf $argv[1]
        case '*.tar.zst'
            tar --zstd -xf $argv[1]
        case '*.tar.lz4'
            tar --use-compress-program=lz4 -xf $argv[1]
        case '*.tar'
            tar -xf $argv[1]
        case '*.zip'
            unzip $argv[1]
        case '*.7z'
            7z x $argv[1]
        case '*.rar'
            unrar x $argv[1]
        case '*.gz'
            gunzip $argv[1]
        case '*.bz2'
            bunzip2 $argv[1]
        case '*.xz'
            unxz $argv[1]
        case '*.zst'
            unzstd $argv[1]
        case '*.lz4'
            unlz4 $argv[1]
        case '*'
            echo "Unknown archive format: $argv[1]"
            return 1
    end

    and echo "Extracted $argv[1]"
end
