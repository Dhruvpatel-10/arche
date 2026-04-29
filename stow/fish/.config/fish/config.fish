# Exit if not interactive
status is-interactive; or return

# ─── Abbreviations (expand inline, show full command in history) ───

# General
abbr -a c clear
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'

# Git
abbr -a g git
abbr -a gcm 'git commit -m'
abbr -a gcam 'git commit -a -m'
abbr -a gcad 'git commit -a --amend'
abbr -a gst 'git status -sb'
abbr -a gd 'git diff'
abbr -a gds 'git diff --staged'
abbr -a glog 'git log --oneline --graph --decorate -20'

# Tmux
abbr -a tn 'tmux new -s'
abbr -a ta 'tmux attach -t'
abbr -a tls 'tmux ls'
abbr -a tk 'tmux kill-session -t'
abbr -a td 'tmux detach'
abbr -a t 'tmux attach; or tmux new'

# Network
abbr -a myipv4 'curl -s ipv4.icanhazip.com'
abbr -a myipv6 'curl -s ipv6.icanhazip.com'

# ─── Aliases (ls/lsa/lt/lta are in functions/) ───

alias ll 'ls -alF'
alias la 'ls -A'
alias ff "fzf --preview 'bat --style=numbers --color=always {}'"
alias printaienv "printenv | grep -E 'GEMINI|OPENAI|GROQ|ANTHROPIC'"

# ─── Machine-specific overrides (gitignored) ───
# PATH and runtime exports live in conf.d/path.fish (auto-sourced).
# Per-user / per-host overrides go in local.fish (gitignored).

set -l local_config $__fish_config_dir/local.fish
test -f $local_config; and source $local_config
