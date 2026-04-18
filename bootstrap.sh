#!/usr/bin/env bash
# bootstrap.sh — orchestrator for fresh Arch Linux setup
# Run: bash bootstrap.sh
#
# Each section prompts before running (y/N). Safe to skip any step.
# Use 'a' at any prompt to run ALL remaining sections without asking.
set -euo pipefail

ARCHE="$(cd "$(dirname "$0")" && pwd)"
export ARCHE

source "$ARCHE/scripts/lib.sh"
log_init

log_info "=== arche bootstrap ==="
log_info "ARCHE=$ARCHE"
log_info "Log: $ARCHE_LOG_FILE"
echo

# ─── Pre-install safety gate ───

log_info "Running pre-install checks..."
echo
if bash "$ARCHE/tests/run.sh" gate; then
    log_ok "All pre-install checks passed"
else
    log_err "Pre-install checks failed — fix the issues above before running bootstrap"
    log_info "Run 'just test' for the full test suite, or 'bash tests/run.sh gate' to re-check"
    exit 1
fi
echo

# ─── Script descriptions (shown at each prompt) ───

declare -A descriptions=(
    [00-preflight]="System checks, pacman config, mirror ranking, full update"
    [01-base]="Core packages (CLI tools, base-devel, git, stow)"
    [02-security]="Firewall, SSH hardening, Tailscale, DNS, kernel hardening, USBGuard"
    [03-gpu]="NVIDIA open driver + CUDA (skipped if no NVIDIA GPU)"
    [04-audio]="PipeWire + WirePlumber audio stack"
    [05-hyprland]="Hyprland compositor, Wayland utils, SDDM (default Breeze theme), rofi"
    [06-shell]="Fish + atuin + fisher + starship"
    [07-panel]="Quickshell panel (bar + control-center + notifications) + arche-shell clone"
    [08-runtimes]="Node.js (fnm), Go, Rust, Bun, Docker"
    [09-apps]="Desktop apps (browser, media, file manager, etc.)"
    [10-stow]="Symlink all stow packages to \$HOME"
    [11-appearance]="Fonts, icons, cursors, GTK theming (nwg-look)"
    [12-boot]="Plymouth splash + sd-encrypt + UKI (rebuilds UKIs; enroll TPM2 separately)"
)

# ─── Run all scripts in order ───

scripts=(
    00-preflight
    01-base
    02-security
    03-gpu
    04-audio
    05-hyprland
    06-shell
    07-panel
    08-runtimes
    09-apps
    10-stow
    11-appearance
    12-boot
)

auto_yes=false
results=()

for script in "${scripts[@]}"; do
    script_path="$ARCHE/scripts/${script}.sh"
    if [[ ! -f "$script_path" ]]; then
        log_warn "Script not found: $script_path — skipping"
        results+=("$script SKIP")
        continue
    fi

    desc="${descriptions[$script]:-}"

    if [[ "$auto_yes" != true ]]; then
        echo ""
        log_section "$script"
        [[ -n "$desc" ]] && log_info "$desc"
        echo ""
        printf "  Run this section? [y/N/a(ll)] "
        read -r choice

        case "$choice" in
            [aA])
                auto_yes=true
                log_info "Running all remaining sections"
                ;;
            [yY])
                ;;
            *)
                log_warn "Skipped $script"
                results+=("$script SKIP")
                continue
                ;;
        esac
    else
        echo ""
        log_info "━━━ Running $script ━━━"
    fi

    rc=0
    bash "$script_path" || rc=$?

    if [[ $rc -eq 0 ]]; then
        results+=("$script OK")
    elif [[ $rc -eq 2 && "$script" == "00-preflight" ]]; then
        # Kernel was upgraded — reboot required before continuing.
        results+=("$script OK (reboot required)")
        echo
        log_warn "═══════════════════════════════════════════════════════════════"
        log_warn "  Kernel was upgraded. Bootstrap is pausing — reboot required."
        log_warn "  Re-run 'bash bootstrap.sh' after reboot; 00-preflight will be"
        log_warn "  a fast no-op and bootstrap will continue with 01-base onward."
        log_warn "═══════════════════════════════════════════════════════════════"
        echo
        printf "  Reboot now? [y/N] "
        read -r choice
        if [[ "$choice" =~ ^[yY]$ ]]; then
            log_info "Rebooting..."
            sudo systemctl reboot
            # reboot terminates the script; exit for safety if it doesn't.
            exit 0
        else
            log_info "Exiting. Reboot manually, then re-run bootstrap.sh."
            exit 0
        fi
    else
        results+=("$script FAIL")
        log_err "$script failed — continuing..."
    fi
done

# ─── Apply theme ───

echo ""
if [[ "$auto_yes" != true ]]; then
    log_section "theme apply"
    log_info "Render all templates with current theme (ember)"
    echo ""
    printf "  Run this section? [y/N] "
    read -r choice
    if [[ ! "$choice" =~ ^[yYaA]$ ]]; then
        log_warn "Skipped theme apply"
        results+=("theme SKIP")
    else
        if bash "$ARCHE/scripts/theme.sh" apply; then
            results+=("theme OK")
        else
            results+=("theme FAIL")
        fi
    fi
else
    log_info "━━━ Applying theme ━━━"
    if bash "$ARCHE/scripts/theme.sh" apply; then
        results+=("theme OK")
    else
        results+=("theme FAIL")
    fi
fi

# ─── Summary ───

echo
log_info "=== Bootstrap Summary ==="
echo
printf '  %-25s %s\n' "SCRIPT" "STATUS"
printf '  %-25s %s\n' "─────────────────────────" "──────"
for result in "${results[@]}"; do
    name="${result% *}"
    status="${result##* }"
    case "$status" in
        OK)   printf '  %-25s \033[1;32m%s\033[0m\n' "$name" "$status" ;;
        FAIL) printf '  %-25s \033[1;31m%s\033[0m\n' "$name" "$status" ;;
        SKIP) printf '  %-25s \033[1;33m%s\033[0m\n' "$name" "$status" ;;
    esac
done
echo

# Check for any failures
if printf '%s\n' "${results[@]}" | grep -q "FAIL"; then
    log_err "Some scripts failed — review output above"
    exit 1
fi

log_ok "Bootstrap complete!"
log_info "Full log: $ARCHE_LOG_FILE"
