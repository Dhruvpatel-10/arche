function extract --description 'Unpack archives (tar/zip/7z/rar/gz/bz2/xz/zst/lz4)'
    argparse h/help l/list 'C/dir=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sextract%s  Unpack one or more archives by file extension\n" $h $d
        printf "%s\n" $m"Dispatches to tar/unzip/7z/unrar/gzip/bzip2/xz/zstd/lz4 based on the extension."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  extract [options] <archive> [archive...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -C, --dir DIR   extract into DIR (created if missing, default: cwd)\n"
        printf "  -l, --list      list contents without extracting\n"
        printf "  -h, --help      show this help\n"
        printf "\n"
        printf "%sSUPPORTED FORMATS%s\n" $k $d
        printf "  tar:    .tar  .tar.gz/.tgz  .tar.bz2/.tbz2  .tar.xz/.txz  .tar.zst  .tar.lz4\n"
        printf "  zip:    .zip  .7z  .rar\n"
        printf "  single: .gz  .bz2  .xz  .zst  .lz4  %s(one file, not an archive)%s\n" $m $d
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  extract backup.tar.xz                    %s# unpack into cwd%s\n" $m $d
        printf "  extract -C /tmp/out photos.zip           %s# unpack into /tmp/out%s\n" $m $d
        printf "  extract -l release.tar.gz                %s# list without unpacking%s\n" $m $d
        printf "  extract *.tar.zst                        %s# unpack many at once%s\n" $m $d
        printf "\n"
        printf "%sNOTES%s\n" $k $d
        printf "  Source archives are kept. Single-file formats decompress to <name> minus the\n"
        printf "  extension (e.g. data.json.gz -> data.json).\n"
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: extract [options] <archive> [archive...]"
        echo "Try 'extract --help' for details."
        return 1
    end

    for arc in $argv
        if not test -f $arc
            echo "File not found: $arc"
            return 1
        end
    end

    if set -q _flag_list
        for arc in $argv
            printf "==> %s\n" $arc
            switch $arc
                case '*.tar.gz' '*.tgz' '*.tar.bz2' '*.tbz2' '*.tar.xz' '*.txz' '*.tar'
                    tar -tf $arc
                case '*.tar.zst'
                    tar --zstd -tf $arc
                case '*.tar.lz4'
                    tar --use-compress-program=lz4 -tf $arc
                case '*.zip'
                    unzip -l $arc
                case '*.7z'
                    7z l $arc
                case '*.rar'
                    unrar l $arc
                case '*.gz' '*.bz2' '*.xz' '*.zst' '*.lz4'
                    printf "  (single-file stream, no index)\n"
                case '*'
                    echo "Unknown archive format: $arc"
                    return 1
            end
            or return $status
        end
        return 0
    end

    set -l dst .
    if set -q _flag_dir
        set dst $_flag_dir
        mkdir -p $dst
        or return 1
    end

    for arc in $argv
        set -l abs (realpath -- $arc)
        set -l name (path basename -- $arc)

        pushd $dst >/dev/null
        or return 1

        switch $arc
            case '*.tar.gz' '*.tgz'
                tar -xzf $abs
            case '*.tar.bz2' '*.tbz2'
                tar -xjf $abs
            case '*.tar.xz' '*.txz'
                tar -xJf $abs
            case '*.tar.zst'
                tar --zstd -xf $abs
            case '*.tar.lz4'
                tar --use-compress-program=lz4 -xf $abs
            case '*.tar'
                tar -xf $abs
            case '*.zip'
                unzip -q $abs
            case '*.7z'
                7z x -y $abs >/dev/null
            case '*.rar'
                unrar x -y $abs
            case '*.gz'
                gzip -dc $abs >(string replace -r '\.gz$' '' -- $name)
            case '*.bz2'
                bzip2 -dc $abs >(string replace -r '\.bz2$' '' -- $name)
            case '*.xz'
                xz -dc $abs >(string replace -r '\.xz$' '' -- $name)
            case '*.zst'
                zstd -dcq $abs >(string replace -r '\.zst$' '' -- $name)
            case '*.lz4'
                lz4 -dcq $abs >(string replace -r '\.lz4$' '' -- $name)
            case '*'
                popd >/dev/null
                echo "Unknown archive format: $arc"
                return 1
        end
        set -l rc $status
        popd >/dev/null
        test $rc -eq 0
        or return $rc
        echo "Extracted $arc -> $dst"
    end
end
