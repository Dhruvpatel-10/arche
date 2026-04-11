#!/usr/bin/env bash
# Transcode video to 1080p h264.
transcode-video-1080p() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: transcode-video-1080p <input>"
        return 1
    fi
    local base="${1%.*}"
    ffmpeg -i "$1" -vf scale=1920:1080 -c:v libx264 -preset fast -crf 23 -c:a copy "${base}-1080p.mp4"
}

# Transcode video to 4K h265.
transcode-video-4k() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: transcode-video-4k <input>"
        return 1
    fi
    local base="${1%.*}"
    ffmpeg -i "$1" -c:v libx265 -preset slow -crf 24 -c:a aac -b:a 192k "${base}-optimized.mp4"
}
