#!/usr/bin/env bash
# 06-shell.sh — fish shell + starship prompt + terminal
source "$(dirname "$0")/lib.sh"

log_info "Setting up shell..."
install_group "$ARCHE/packages/shell.sh"

# Set fish as default shell
fish_path="$(command -v fish)"
if [[ -n "$fish_path" ]]; then
    # Add fish to /etc/shells if missing
    if ! grep -qx "$fish_path" /etc/shells; then
        log_info "Adding fish to /etc/shells..."
        echo "$fish_path" | sudo tee -a /etc/shells > /dev/null
    fi

    # Change default shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" != "$fish_path" ]]; then
        log_info "Changing default shell to fish..."
        chsh -s "$fish_path"
        log_ok "Default shell set to fish"
    else
        log_warn "Fish already default shell"
    fi
else
    log_err "fish not found after install"
fi

# Stow configs
stow_pkg fish

# Render starship prompt (template-only — colors from active theme)
theme_render starship

# Install fisher + plugins
if command -v fish &>/dev/null; then
    if [[ ! -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        log_info "Installing fisher..."
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
        log_ok "Fisher installed"
    else
        log_warn "Fisher already installed"
    fi

    # Install plugins from fish_plugins
    log_info "Updating fisher plugins..."
    fish -c 'fisher update' 2>/dev/null || true
fi

log_ok "Shell setup done"
