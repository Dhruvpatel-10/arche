function clip-save --description 'Save clipboard image as PNG'
    argparse h/help o/open c/copy-path -- $argv
    or return

    if set -q _flag_help
        echo "Usage: clip-save [-o] [-c] [DIR] [NAME]"
        echo ""
        echo "  (no args)       ./clip-<timestamp>.png"
        echo "  NAME            ./NAME.png       (.png auto-appended)"
        echo "  DIR             DIR/clip-<timestamp>.png"
        echo "  DIR NAME        DIR/NAME.png"
        echo ""
        echo "  -o              xdg-open the saved file"
        echo "  -c              copy resulting path to clipboard"
        echo "  flags combine:  clip-save -oc ~/Pictures diagram"
        return 0
    end

    if not wl-paste -l 2>/dev/null | string match -rq '^image/'
        echo "clipboard does not contain an image" >&2
        return 1
    end

    set -l stamp (date +%Y%m%d-%H%M%S)
    set -l a $argv[1]
    set -l b $argv[2]
    set -l dest

    if test -n "$b"
        if not test -d "$a"
            echo "clip-save: '$a' is not a directory" >&2
            return 1
        end
        set -l name $b
        string match -rq '\.png$' -- $name; or set name $name.png
        set dest (string trim -r -c / -- $a)/$name
    else if test -z "$a"
        set dest (pwd)/clip-$stamp.png
    else if test -d "$a"
        set dest (string trim -r -c / -- $a)/clip-$stamp.png
    else if string match -rq '\.png$' -- $a
        set dest $a
    else
        set dest $a.png
    end

    wl-paste -t image/png > $dest
    if test ! -s $dest
        rm -f $dest
        echo "failed to save image" >&2
        return 1
    end

    echo $dest
    set -q _flag_copy_path; and echo -n $dest | wl-copy
    set -q _flag_open;      and xdg-open $dest &>/dev/null &
end
