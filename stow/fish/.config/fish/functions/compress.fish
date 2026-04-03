function compress --description 'Compress directory to tar.gz'
    if test (count $argv) -ne 1
        echo "Usage: compress <directory>"
        return 1
    end
    tar -czf (string trim -r -c / $argv[1]).tar.gz (string trim -r -c / $argv[1])
end
