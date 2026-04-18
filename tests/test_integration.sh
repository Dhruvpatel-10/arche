#!/usr/bin/env bash
# test_integration.sh — live system verification (needs installed state)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.

test_integration() {

    # ── Shell ──

    section "Integration: Shell"

    if command -v bash &>/dev/null; then
        if bash -lc 'echo ok' &>/dev/null; then
            pass "bash loads cleanly"
        else
            fail "bash fails to load"
        fi
    else
        fail "bash not installed"
    fi

    # fish must be installed and runnable
    if command -v fish &>/dev/null && fish -c 'echo ok' &>/dev/null; then
        pass "fish runnable"
    else
        fail "fish not runnable"
    fi

    # fisher installed in user's fish functions dir
    if [[ -f "$HOME/.config/fish/functions/fisher.fish" ]]; then
        pass "fisher installed"
    else
        fail "fisher missing — run scripts/06-shell.sh"
    fi

    # ── Core tools ──

    section "Integration: Core tools"

    local tools=(git stow just eza bat rg fd fzf zoxide bash atuin starship kitty paru)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            pass "$tool in PATH"
        else
            skip "$tool not installed"
        fi
    done

    # ── Custom binaries ──

    section "Integration: Custom binaries"

    local bins=(arche-legion)
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
        "$HOME/.config/kitty/theme.conf"
        "$HOME/.config/btop/arche.theme"
        "$HOME/.config/tmux/colors.conf"
        "$HOME/.config/gtk-4.0/gtk.css"
        "$HOME/.config/zathura/zathurarc-colors"
        "$HOME/.local/share/color-schemes/Ember.colors"
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

    # ── Theme value spot-checks ──
    # Source the active theme and verify key values actually landed in rendered files.

    section "Integration: Theme values in rendered output"

    if [[ -f "$ARCHE/themes/active" ]]; then
        if (source "$ARCHE/themes/active" 2>/dev/null); then
            pass "active theme sources cleanly"
        else
            fail "active theme fails to source"
        fi

        # Read expected values from active theme
        local accent bg fg font_mono
        eval "$(source "$ARCHE/themes/active" && echo "accent=$COLOR_ACCENT bg=$COLOR_BG fg=$COLOR_FG font_mono=\"$FONT_MONO\"")"

        # Spot-check: bg color in kitty/theme.conf
        if [[ -f "$HOME/.config/kitty/theme.conf" ]]; then
            if grep -qi "${bg}" "$HOME/.config/kitty/theme.conf" 2>/dev/null; then
                pass "kitty theme.conf contains bg (${bg})"
            else
                fail "kitty theme.conf missing bg color"
            fi
        fi

        # Spot-check: accent color in KDE color scheme (RGB triplet)
        local kde_scheme="$HOME/.local/share/color-schemes/Ember.colors"
        if [[ -f "$kde_scheme" ]]; then
            local hex="${accent#\#}"
            local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
            if grep -qF "${r},${g},${b}" "$kde_scheme" 2>/dev/null; then
                pass "KDE Ember.colors contains accent RGB (${r},${g},${b})"
            else
                fail "KDE Ember.colors missing accent RGB"
            fi
        fi

        # Spot-check: fg color in gtk-4.0/gtk.css
        if [[ -f "$HOME/.config/gtk-4.0/gtk.css" ]]; then
            if grep -qi "${fg}" "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null; then
                pass "gtk.css contains fg (${fg})"
            else
                fail "gtk.css missing fg color"
            fi
        fi
    else
        skip "no active theme — skipping value checks"
    fi

    # ── Services ──

    section "Integration: Services"

    local services=(sddm pipewire wireplumber ufw systemd-resolved)
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
        ["kernel.unprivileged_bpf_disabled"]="1"
        ["kernel.kptr_restrict"]="2"
        ["fs.protected_symlinks"]="1"
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

    # ── DNS ──

    section "Integration: Encrypted DNS"

    if grep -q 'DNSOverTLS=yes' /etc/systemd/resolved.conf 2>/dev/null; then
        pass "DNS-over-TLS enabled"
        if grep -q 'dns.nextdns.io' /etc/systemd/resolved.conf 2>/dev/null; then
            pass "NextDNS configured"
        else
            skip "NextDNS not rendered yet (run 02-security.sh)"
        fi
    else
        skip "DNS-over-TLS not deployed yet (run 02-security.sh)"
    fi

    # ── Secrets ──

    section "Integration: Secrets"

    if [[ -f "$ARCHE/secrets.sh" ]]; then
        pass "secrets.sh exists"
    else
        skip "secrets.sh not created yet (see secrets.sh.example)"
    fi
}
