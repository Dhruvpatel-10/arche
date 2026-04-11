#!/usr/bin/env bash
# 06-shell.sh — bash + ble.sh + bash-preexec + atuin + carapace + starship
# See docs/decisions.md D016 (reverses D003).
#
# ble.sh and bash-preexec are sourced directly from /opt/arche/vendor/ —
# no system install step. carapace is a vendored binary symlinked into
# ~/.local/bin/arche/.

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

# ── Symlink vendored carapace binary into ~/.local/bin/arche/ ──

mkdir -p "$HOME/.local/bin/arche"
if [[ -x "$ARCHE/tools/bin/carapace" ]]; then
    ln -sf "$ARCHE/tools/bin/carapace" "$HOME/.local/bin/arche/carapace"
    log_ok "Linked carapace → ~/.local/bin/arche/carapace"
else
    log_warn "tools/bin/carapace missing — skipping symlink"
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
