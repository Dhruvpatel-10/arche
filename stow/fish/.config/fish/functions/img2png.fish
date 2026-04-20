function img2png --description 'Convert image(s) to max-compression lossless PNG'
    argparse h/help 'o/output=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%simg2png%s  Convert image(s) to heavily compressed, metadata-stripped PNG\n" $h $d
        printf "%s\n" $m"Wraps ImageMagick with the best PNG zlib settings (lossless)."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  img2png [options] <input> [input...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -o, --output FILE  output path (single input only, .png appended if missing)\n"
        printf "  -h, --help         show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  img2png photo.jpg                  %s# photo.png%s\n" $m $d
        printf "  img2png *.jpg                      %s# one .png per input%s\n" $m $d
        printf "  img2png -o out photo.jpg           %s# out.png (ext appended)%s\n" $m $d
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: img2png [options] <input> [input...]"
        return 1
    end

    for f in $argv
        if not test -f $f
            echo "File not found: $f"
            return 1
        end
    end

    if set -q _flag_output; and test (count $argv) -gt 1
        echo "--output requires a single input file"
        return 1
    end

    for f in $argv
        set -l out
        if set -q _flag_output
            set out $_flag_output
            string match -q -- '*.png' $out; or set out $out.png
        else
            set out (string replace -r '\.[^.]+$' '' -- $f).png
        end
        magick $f -strip \
            -define png:compression-filter=5 \
            -define png:compression-level=9 \
            -define png:compression-strategy=1 \
            -define png:exclude-chunk=all \
            $out
        or return 1
        echo "Wrote $out"
    end
end
