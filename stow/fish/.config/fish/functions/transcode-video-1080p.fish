function transcode-video-1080p --description 'Transcode video to 1080p h264'
    if test (count $argv) -ne 1
        echo "Usage: transcode-video-1080p <input>"
        return 1
    end
    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    ffmpeg -i $argv[1] -vf scale=1920:1080 -c:v libx264 -preset fast -crf 23 -c:a copy {$base}-1080p.mp4
end
