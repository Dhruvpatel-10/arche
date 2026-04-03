function img2jpg-small --description 'Convert image to small JPG (1080px max)'
    if test (count $argv) -ne 1
        echo "Usage: img2jpg-small <input>"
        return 1
    end
    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    magick $argv[1] -resize '1080x>' -quality 95 -strip {$base}.jpg
end
