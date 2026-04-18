#!/usr/bin/env bash
# 08-runtimes.sh — development languages and toolchains
source "$(dirname "$0")/lib.sh"

log_info "Setting up runtimes..."
install_group "$ARCHE/packages/runtimes.sh"

# fnm (Node version manager) — installed via its own script
if ! command -v fnm &>/dev/null; then
    log_info "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    log_ok "fnm installed (restart shell to use)"
else
    log_warn "fnm already installed: $(fnm --version)"
fi

# Install latest LTS Node via fnm
if command -v fnm &>/dev/null; then
    if ! fnm ls | grep -q "lts-latest" 2>/dev/null; then
        log_info "Installing Node LTS via fnm..."
        fnm install --lts
        fnm default lts-latest
    else
        log_warn "Node LTS already installed"
    fi
fi

# Bun — installed via official script
if ! command -v bun &>/dev/null; then
    log_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    log_ok "Bun installed (restart shell to use)"
else
    log_warn "Bun already installed: $(bun --version)"
fi

# Verify key runtimes
for cmd in go rustc ruby node bun; do
    if command -v "$cmd" &>/dev/null; then
        log_ok "$cmd: $("$cmd" --version 2>/dev/null | head -1)"
    else
        log_warn "$cmd not found"
    fi
done

log_ok "Runtimes setup done"
