function lta --wraps=eza --description 'eza tree view with hidden files'
    if command -q eza
        eza --tree --level=2 --long --icons --git -a $argv
    else
        command ls -Ra $argv
    end
end
