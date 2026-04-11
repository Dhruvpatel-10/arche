# Zoxide — smarter cd

if command -q zoxide
    # Style the interactive picker (cdi or cd <query><space><tab>)
    set -gx _ZO_FZF_OPTS "\
--height=50% \
--layout=reverse \
--border=rounded \
--preview='command eza -la --color=always --icons=auto --group-directories-first {2..}' \
--preview-window='right:40%:border-left' \
--no-sort \
--keep-right \
--info=inline \
--color=bg+:#313244,fg+:#cdd6f4,hl:#89b4fa,hl+:#89b4fa \
--color=border:#45475a,info:#6c7086,pointer:#f5c2e7,marker:#a6e3a1 \
--color=prompt:#89b4fa,spinner:#f5c2e7,header:#6c7086"

    zoxide init --cmd cd fish | source
end
