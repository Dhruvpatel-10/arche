#!/usr/bin/env bash
# 06-shell.sh — bash + bash-completion + ble.sh + bash-preexec + atuin + starship
# See docs/decisions.md D016 (reverses D003).
#
# ble.sh and bash-preexec are sourced directly from /opt/arche/vendor/ —
# no system install step. Per-tool completions come from bash-completion
# (extra repo), sourced in .bashrc.

source "$(dirname "$0")/lib.sh"

log_info "Setting up shell..."
install_group "$ARCHE/packages/shell.sh"

# ── Set bash as default shell ──

bash_path="$(command -v bash)"
if [[ -n "$bash_path" ]]; then
    if ! grep -qx "$bash_path" /etc/shells; then
        log_info "Adding bash to /etc/shells..."
        echo "$bash_path" | sudo tee -a /etc/shells > /dev/null
    fi

    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" != "$bash_path" ]]; then
        log_info "Changing default shell to bash..."
        chsh -s "$bash_path"
        log_ok "Default shell set to bash"
    else
        log_warn "Bash already default shell"
    fi
else
    log_err "bash not found after install"
fi

# ── Verify vendored ble.sh + bash-preexec are readable ──

for f in "$ARCHE/vendor/blesh/ble.sh" "$ARCHE/vendor/bash-preexec/bash-preexec.sh"; do
    if [[ -r "$f" ]]; then
        log_ok "vendored: ${f#$ARCHE/}"
    else
        log_err "missing vendor file: ${f#$ARCHE/}"
    fi
done

# ── Stow bash package ──

stow_pkg bash

# ── Render starship prompt (template-only — colors from active theme) ──

theme_render starship

log_ok "Shell setup done"
