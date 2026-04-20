function img2jpg --description 'Convert image(s) to JPG (quality/resize tunable)'
    argparse h/help 'q/quality=' 'r/resize=' 'o/output=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%simg2jpg%s  Convert image(s) to JPG, stripping metadata\n" $h $d
        printf "%s\n" $m"Wraps ImageMagick. Default quality 95; -r downscales in one step."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  img2jpg [options] <input> [input...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -q, --quality N    JPG quality 1-100 (default 95)\n"
        printf "  -r, --resize SPEC  downscale only if larger:\n"
        printf "                       N        -> NxN bounding box (keep aspect)\n"
        printf "                       WIDTHx   -> width-only (keep aspect)\n"
        printf "                       WxH      -> WxH bounding box\n"
        printf "  -o, --output FILE  output path (single input only, .jpg appended if missing)\n"
        printf "  -h, --help         show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  img2jpg photo.png                  %s# photo.jpg, q95%s\n" $m $d
        printf "  img2jpg -q 80 -r 1080 photo.png    %s# lower q, cap at 1080 each side%s\n" $m $d
        printf "  img2jpg -r 1920x *.png             %s# batch, width-cap 1920%s\n" $m $d
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: img2jpg [options] <input> [input...]"
        return 1
    end

    for f in $argv
        if not test -f $f
            echo "File not found: $f"
            return 1
        end
    end

    set -l quality 95
    if set -q _flag_quality
        if not string match -qr '^[0-9]+$' -- $_flag_quality
            echo "Invalid quality: $_flag_quality (expected 1-100)"
            return 1
        end
        if test $_flag_quality -lt 1 -o $_flag_quality -gt 100
            echo "Invalid quality: $_flag_quality (expected 1-100)"
            return 1
        end
        set quality $_flag_quality
    end

    if set -q _flag_output; and test (count $argv) -gt 1
        echo "--output requires a single input file"
        return 1
    end

    set -l resize_args
    if set -q _flag_resize
        set -l spec $_flag_resize
        string match -qr '^[0-9]+$' -- $spec; and set spec {$spec}x{$spec}
        set resize_args -resize "$spec>"
    end

    for f in $argv
        set -l out
        if set -q _flag_output
            set out $_flag_output
            if not string match -q -- '*.jpg' $out; and not string match -q -- '*.jpeg' $out
                set out $out.jpg
            end
        else
            set out (string replace -r '\.[^.]+$' '' -- $f).jpg
        end
        magick $f $resize_args -quality $quality -strip $out
        or return 1
        echo "Wrote $out"
    end
end
