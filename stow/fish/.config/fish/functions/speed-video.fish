function speed-video --description 'Speed up/down video with optional quality and trimming'
    argparse h/help s/speed= q/quality= p/preset= o/output= start= end= trim-start= trim-end= -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sspeed-video%s  Change video speed with ffmpeg\n" $h $d
        printf "%s\n" $m"Defaults to 1.4x and high-quality H.264 output. Trim values may use decimals."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  speed-video [options] <input>\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -s, --speed N          playback speed multiplier (default 1.4)\n"
        printf "  -q, --quality VALUE    good | best | small | CRF number 0-51 (default good)\n"
        printf "  -p, --preset PRESET    x264 preset (default slow)\n"
        printf "  -o, --output FILE      output path (default <input>-<speed>x.mp4)\n"
        printf "      --start TIME       keep from timestamp/seconds, e.g. 2.5 or 00:00:02.500\n"
        printf "      --end TIME         keep until timestamp/seconds, e.g. 12.75\n"
        printf "      --trim-start SEC   remove seconds from the start, e.g. 0.250\n"
        printf "      --trim-end SEC     remove seconds from the end, e.g. 1.5\n"
        printf "  -h, --help             show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  speed-video clip.mp4\n"
        printf "  speed-video -s 1.25 -q best clip.mp4\n"
        printf "  speed-video --trim-start 0.4 --trim-end 1.2 clip.mp4\n"
        printf "  speed-video --start 3.250 --end 12.800 -o out.mp4 clip.mp4\n"
        return 0
    end

    if test (count $argv) -ne 1
        echo "Usage: speed-video [options] <input>"
        echo "Try 'speed-video --help' for details."
        return 1
    end

    set -l input $argv[1]
    if not test -f $input
        echo "File not found: $input"
        return 1
    end

    if not command -q ffmpeg
        echo "ffmpeg not found"
        return 1
    end

    set -l speed 1.4
    set -q _flag_speed; and set speed $_flag_speed
    if not string match -qr '^[0-9]+([.][0-9]+)?$' -- $speed
        echo "Invalid speed: $speed"
        return 1
    end
    if string match -qr '^0+([.]0+)?$' -- $speed
        echo "Invalid speed: $speed (must be greater than 0)"
        return 1
    end

    set -l quality good
    set -q _flag_quality; and set quality $_flag_quality

    set -l crf
    switch $quality
        case good high
            set crf 18
        case best
            set crf 15
        case small
            set crf 23
        case '*'
            if not string match -qr '^[0-9]+$' -- $quality
                echo "Invalid quality: $quality (use good, best, small, or CRF 0-51)"
                return 1
            end
            if test $quality -lt 0 -o $quality -gt 51
                echo "Invalid quality: $quality (CRF must be 0-51)"
                return 1
            end
            set crf $quality
    end

    set -l preset slow
    set -q _flag_preset; and set preset $_flag_preset

    if set -q _flag_start; and set -q _flag_trim_start
        echo "Use either --start or --trim-start, not both"
        return 1
    end
    if set -q _flag_end; and set -q _flag_trim_end
        echo "Use either --end or --trim-end, not both"
        return 1
    end

    set -l start_args
    if set -q _flag_start
        set start_args -ss $_flag_start
    else if set -q _flag_trim_start
        if not string match -qr '^[0-9]+([.][0-9]+)?$' -- $_flag_trim_start
            echo "Invalid --trim-start: $_flag_trim_start"
            return 1
        end
        set start_args -ss $_flag_trim_start
    end

    set -l end_args
    if set -q _flag_end
        set end_args -to $_flag_end
    else if set -q _flag_trim_end
        if not string match -qr '^[0-9]+([.][0-9]+)?$' -- $_flag_trim_end
            echo "Invalid --trim-end: $_flag_trim_end"
            return 1
        end
        if not command -q ffprobe
            echo "ffprobe not found (needed for --trim-end)"
            return 1
        end

        set -l duration (ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- $input)
        or return 1
        if test -z "$duration"
            echo "Could not read video duration"
            return 1
        end

        set -l end_at (math "$duration - $_flag_trim_end")
        if string match -qr '^-|^0+([.]0+)?$' -- $end_at
            echo "--trim-end is greater than or equal to video duration"
            return 1
        end
        set end_args -to $end_at
    end

    set -l output
    if set -q _flag_output
        set output $_flag_output
    else
        set -l base (string replace -r '\.[^.]+$' '' -- $input)
        set -l clean_speed (string replace -a '.' 'p' -- $speed)
        set output {$base}-{$clean_speed}x.mp4
    end

    set -l video_filter "setpts=PTS/$speed"
    set -l audio_args
    set -l has_audio 1

    if command -q ffprobe
        set -l audio_streams (ffprobe -v error -select_streams a:0 -show_entries stream=index -of csv=p=0 -- $input)
        test -z "$audio_streams"; and set has_audio 0
    end

    if test $has_audio -eq 1
        set -l atempo_filters
        set -l tempo $speed
        while true
            set -l diff (math "$tempo - 2.0")
            if string match -qr '^-|^0+([.]0+)?$' -- $diff
                break
            end
            set -a atempo_filters atempo=2.0
            set tempo (math "$tempo / 2.0")
        end
        while true
            set -l diff (math "$tempo - 0.5")
            if not string match -qr '^-' -- $diff
                break
            end
            set -a atempo_filters atempo=0.5
            set tempo (math "$tempo / 0.5")
        end
        set -a atempo_filters atempo=$tempo

        set -l audio_filter (string join ',' -- $atempo_filters)
        set audio_args -filter:a $audio_filter -c:a aac -b:a 192k
    else
        set audio_args -an
    end

    ffmpeg $start_args $end_args -i $input \
        -filter:v $video_filter \
        -c:v libx264 -preset $preset -crf $crf \
        $audio_args \
        -movflags +faststart \
        $output
end
