function img2jpg --description 'Convert image to high-quality JPG'
    if test (count $argv) -ne 1
        echo "Usage: img2jpg <input>"
        return 1
    end
    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    magick $argv[1] -quality 95 -strip {$base}.jpg
end
