#!/usr/bin/env bash
# Static bash aliases (always active, no expansion).
# Abbreviations live in ~/.blerc — ble.sh sources them after attach.

alias ll='ls -alF'
alias la='ls -A'
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
alias decompress='tar -xzf'
alias printaienv="printenv | grep -E 'GEMINI|OPENAI|GROQ|ANTHROPIC'"
