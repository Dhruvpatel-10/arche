function lt --wraps=eza --description 'eza tree view'
    if command -q eza
        eza --tree --level=2 --long --icons --git $argv
    else
        command ls -R $argv
    end
end
