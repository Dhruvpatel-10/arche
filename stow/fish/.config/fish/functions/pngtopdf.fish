function pngtopdf --description 'Convert PNG to PDF'
    if test (count $argv) -lt 1 -o (count $argv) -gt 2
        echo "Usage: pngtopdf <input.png> [output.pdf]"
        return 1
    end

    if not test -f $argv[1]
        echo "Error: input file not found: $argv[1]"
        return 1
    end

    set -l base (string replace -r '\.[^.]+$' '' $argv[1])
    set -l output (test (count $argv) -eq 2; and echo $argv[2]; or echo {$base}.pdf)
    magick -density 300 $argv[1] -quality 100 $output
end
