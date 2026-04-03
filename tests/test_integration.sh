#!/usr/bin/env bash
# test_integration.sh — live system verification (needs installed state)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.

test_integration() {

    # ── Shell ──

    section "Integration: Shell"

    if command -v fish &>/dev/null; then
        if fish -c 'echo ok' &>/dev/null; then
            pass "fish loads cleanly"
        else
            fail "fish fails to load"
        fi
    else
        skip "fish not installed"
    fi

    # ── Core tools ──

    section "Integration: Core tools"

    local tools=(git stow just eza bat rg fd fzf zoxide fish starship kitty paru)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            pass "$tool in PATH"
        else
            skip "$tool not installed"
        fi
    done

    # ── Custom binaries ──

    section "Integration: Custom binaries"

    local bins=(arche-legion arche-greeter)
    for bin in "${bins[@]}"; do
        local path="$ARCHE/tools/bin/$bin"
        if [[ -x "$path" ]]; then
            pass "$bin exists and is executable"
        else
            fail "$bin missing or not executable in tools/bin/"
        fi
    done

    if [[ -L "$HOME/.local/bin/arche/arche-legion" ]]; then
        local target
        target=$(readlink -f "$HOME/.local/bin/arche/arche-legion")
        if [[ "$target" == *"tools/bin/arche-legion" ]]; then
            pass "arche-legion symlinked correctly"
        else
            fail "arche-legion symlink points to wrong target: $target"
        fi
    else
        skip "arche-legion not symlinked yet"
    fi

    # ── Rendered templates ──

    section "Integration: Rendered templates"

    local rendered=(
        "$HOME/.config/hypr/colors.conf"
        "$HOME/.config/kitty/theme.conf"
        "$HOME/.config/waybar/style.css"
        "$HOME/.config/rofi/theme.rasi"
        "$HOME/.config/mako/config"
    )
    for f in "${rendered[@]}"; do
        if [[ -f "$f" ]]; then
            if grep -qE '\$\{[A-Z_]+\}' "$f" 2>/dev/null; then
                fail "$(basename "$f") has unsubstituted variables"
            else
                pass "$(basename "$f") rendered"
            fi
        else
            skip "$(basename "$f") not rendered yet"
        fi
    done

    # ── Theme ──

    section "Integration: Theme"

    if [[ -f "$ARCHE/themes/active" ]]; then
        if (source "$ARCHE/themes/active" 2>/dev/null); then
            pass "active theme sources cleanly"
        else
            fail "active theme fails to source"
        fi
    else
        skip "no active theme"
    fi

    # ── Services ──

    section "Integration: Services"

    local services=(greetd pipewire wireplumber ufw systemd-resolved)
    for svc in "${services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            pass "$svc enabled"
        else
            skip "$svc not enabled"
        fi
    done

    local user_services=(pipewire pipewire-pulse wireplumber)
    for svc in "${user_services[@]}"; do
        if systemctl --user is-active "$svc" &>/dev/null; then
            pass "$svc (user) active"
        else
            skip "$svc (user) not active"
        fi
    done

    # ── Kernel hardening ──

    section "Integration: Kernel hardening"

    local -A sysctl_checks=(
        ["net.ipv4.tcp_syncookies"]="1"
        ["kernel.yama.ptrace_scope"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
    )
    for key in "${!sysctl_checks[@]}"; do
        local expected="${sysctl_checks[$key]}"
        local actual
        actual=$(sysctl -n "$key" 2>/dev/null || echo "")
        if [[ "$actual" == "$expected" ]]; then
            pass "sysctl $key = $expected"
        else
            skip "sysctl $key = ${actual:-unset} (expected $expected)"
        fi
    done

    # ── Secrets ──

    section "Integration: Secrets"

    if [[ -f "$ARCHE/secrets.sh" ]]; then
        pass "secrets.sh exists"
    else
        skip "secrets.sh not created yet (see secrets.sh.example)"
    fi
}
