function ls --wraps=eza --description 'eza with icons and grouping'
    if command -q eza
        eza -lh --group-directories-first --icons=auto $argv
    else
        command ls --color=auto $argv
    end
end
