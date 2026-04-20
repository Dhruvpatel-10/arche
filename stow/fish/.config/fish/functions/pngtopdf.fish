function pngtopdf --description 'Convert PNG(s) to PDF at 300 DPI'
    argparse h/help 'o/output=' -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%spngtopdf%s  Convert PNG(s) to PDF at 300 DPI, quality 100\n" $h $d
        printf "%s\n" $m"One input -> one PDF. ImageMagick handles the raster->vector embed."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  pngtopdf [options] <input.png> [input.png...]\n"
        printf "\n"
        printf "%sOPTIONS%s\n" $k $d
        printf "  -o, --output FILE  output path (single input only, .pdf appended if missing)\n"
        printf "  -h, --help         show this help\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  pngtopdf scan.png                  %s# scan.pdf%s\n" $m $d
        printf "  pngtopdf -o report page.png        %s# report.pdf (ext appended)%s\n" $m $d
        printf "  pngtopdf *.png                     %s# one .pdf per image%s\n" $m $d
        return 0
    end

    if test (count $argv) -lt 1
        echo "Usage: pngtopdf [options] <input.png> [input.png...]"
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
            string match -q -- '*.pdf' $out; or set out $out.pdf
        else
            set out (string replace -r '\.[^.]+$' '' -- $f).pdf
        end
        magick -density 300 $f -quality 100 $out
        or return 1
        echo "Wrote $out"
    end
end
