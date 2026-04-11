#!/usr/bin/env bash
# ~/.bashrc — arche interactive bash config
# See docs/decisions.md D016 for the migration from fish.
#
# Load order matters: bash-completion → bash-preexec → ble.sh → tool
# integrations (atuin must come after bash-preexec) → functions →
# aliases/abbreviations → local secrets. ble.sh auto-attaches on first prompt.

# Exit if non-interactive
[[ $- == *i* ]] || return

# ── Shell options ──
# Atuin is the real history layer (SQLite, fuzzy Ctrl-R). Bash history is
# just a recency cache, so we skip the O(n²) erasedups scan and keep the
# in-memory buffer small.
HISTCONTROL=ignoredups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize cmdhist globstar

# ── PATH + env (must run before any command lookups) ──
[[ -r "$HOME/.bash/conf.d/00-path.sh" ]] && source "$HOME/.bash/conf.d/00-path.sh"

# ── bash-completion (system tool completions: git, docker, systemd, etc.) ──
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
    # shellcheck source=/dev/null
    source /usr/share/bash-completion/bash_completion
fi

# ── bash-preexec hooks (required by Atuin; vendored — D016) ──
if [[ -r /opt/arche/vendor/bash-preexec/bash-preexec.sh ]]; then
    # shellcheck source=/dev/null
    source /opt/arche/vendor/bash-preexec/bash-preexec.sh
fi

# ── ble.sh: autosuggest + syntax highlight + abbreviations (vendored — D016) ──
# --attach=prompt defers the heavy attach work to the first PROMPT_COMMAND,
# so .bashrc returns faster and the shell feels snappier on launch.
if [[ -r /opt/arche/vendor/blesh/ble.sh ]]; then
    # shellcheck source=/dev/null
    source /opt/arche/vendor/blesh/ble.sh --attach=prompt
fi

# ── Tool integrations (starship, zoxide, fnm, uv, ssh-agent, atuin) ──
if [[ -d "$HOME/.bash/conf.d" ]]; then
    for _f in "$HOME"/.bash/conf.d/[1-9]*.sh; do
        [[ -r "$_f" ]] && source "$_f"
    done
    unset _f
fi

# ── Functions (ported from fish — see functions/ dir) ──
if [[ -d "$HOME/.bash/functions" ]]; then
    for _f in "$HOME"/.bash/functions/*.sh; do
        [[ -r "$_f" ]] && source "$_f"
    done
    unset _f
fi

# ── Aliases + ble.sh abbreviations ──
[[ -r "$HOME/.bash/aliases.sh" ]] && source "$HOME/.bash/aliases.sh"

# ── Machine-specific overrides (gitignored secrets) ──
[[ -r "$HOME/.bash/local.bash" ]] && source "$HOME/.bash/local.bash"

# ble.sh attaches automatically on first prompt (--attach=prompt above),
# so no explicit ble-attach is needed here.
