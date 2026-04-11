function lsa --wraps=eza --description 'eza all files'
    if command -q eza
        eza -lah --group-directories-first --icons=auto $argv
    else
        command ls -lah --color=auto $argv
    end
end
