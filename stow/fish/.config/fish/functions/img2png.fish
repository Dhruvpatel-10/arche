function img2png --description 'Convert image to compressed lossless PNG'
    if test (count $argv) -ne 1
        echo "Usage: img2png <input>"
        return 1
    end
    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    magick $argv[1] -strip \
        -define png:compression-filter=5 \
        -define png:compression-level=9 \
        -define png:compression-strategy=1 \
        -define png:exclude-chunk=all \
        {$base}.png
end
