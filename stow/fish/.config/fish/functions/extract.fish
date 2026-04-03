function extract --description 'Extract any common archive format'
    if test (count $argv) -ne 1
        echo "Usage: extract <archive>"
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
        case '*'
            echo "Unknown archive format: $argv[1]"
            return 1
    end
end
