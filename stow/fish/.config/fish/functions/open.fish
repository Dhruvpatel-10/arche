function open --description 'Open file with default application'
    xdg-open $argv >/dev/null 2>&1 &
    disown
end
