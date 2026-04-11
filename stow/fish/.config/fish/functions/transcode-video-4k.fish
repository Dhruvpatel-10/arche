function transcode-video-4k --description 'Transcode video to 4K h265'
    if test (count $argv) -ne 1
        echo "Usage: transcode-video-4k <input>"
        return 1
    end
    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    ffmpeg -i $argv[1] -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k {$base}-optimized.mp4
end
