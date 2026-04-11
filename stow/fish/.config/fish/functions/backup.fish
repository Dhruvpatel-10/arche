function backup --description 'Create a timestamped backup of a file'
    if test (count $argv) -ne 1
        echo "Usage: backup <file>"
        return 1
    end
    if not test -e $argv[1]
        echo "File not found: $argv[1]"
        return 1
    end
    cp $argv[1] $argv[1].(date +%Y%m%d-%H%M%S).bak
    and echo "Backed up to $argv[1]."(date +%Y%m%d-%H%M%S)".bak"
end
