function icat --description 'Display image(s) inline in kitty terminal'
    argparse h/help -- $argv
    or return 1

    if set -q _flag_help
        set -l h (set_color --bold brcyan)
        set -l k (set_color --bold)
        set -l d (set_color normal)
        set -l m (set_color brblack)

        printf "%sicat%s  Render image(s) inline in the terminal\n" $h $d
        printf "%s\n" $m"Wraps 'kitten icat' — kitty's graphics-protocol image viewer."$d
        printf "\n"
        printf "%sUSAGE%s\n" $k $d
        printf "  icat <image> [image...]\n"
        printf "\n"
        printf "%sEXAMPLES%s\n" $k $d
        printf "  icat photo.jpg                 %s# show inline%s\n" $m $d
        printf "  icat *.png                     %s# show a batch%s\n" $m $d
        printf "\n"
        printf "%sNOTES%s\n" $k $d
        printf "  Requires kitty terminal (or any emulator with kitty graphics support).\n"
        printf "  For a pop-up viewer via the desktop's default app, use 'open <image>'.\n"
        return 0
    end

    if not command -q kitten
        echo "icat: 'kitten' not found (install kitty terminal)"
        return 1
    end

    if test (count $argv) -lt 1
        echo "Usage: icat <image> [image...]"
        return 1
    end

    for img in $argv
        if not test -f $img
            echo "File not found: $img"
            return 1
        end
    end

    kitten icat $argv
end
