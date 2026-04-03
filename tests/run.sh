#!/usr/bin/env bash
# tests/run.sh — arche test runner
# Usage: bash tests/run.sh [lint|stow|integration|all]
#   lint        — syntax + shellcheck (no root, CI-safe)
#   stow        — dry-run stow conflicts (no root)
#   integration — verify installed state (needs live system)
#   all         — run everything

set -euo pipefail

ARCHE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# ─── Helpers ───

pass() { PASS=$((PASS + 1)); printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '\033[1;31m  ✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '\033[1;33m  ~\033[0m %s\n' "$*"; }

section() { printf '\n\033[1;36m── %s ──\033[0m\n' "$*"; }

summary() {
    echo ""
    section "Results"
    printf '  pass: %d  fail: %d  skip: %d\n' "$PASS" "$FAIL" "$SKIP"
    [[ $FAIL -gt 0 ]] && exit 1 || exit 0
}

# ─── Lint Tests ───

test_lint() {
    section "Lint: Bash syntax"

    for f in "$ARCHE"/scripts/*.sh; do
        if bash -n "$f" 2>/dev/null; then
            pass "bash -n $(basename "$f")"
        else
            fail "bash -n $(basename "$f")"
        fi
    done

    for f in "$ARCHE"/packages/*.sh; do
        if bash -n "$f" 2>/dev/null; then
            pass "bash -n packages/$(basename "$f")"
        else
            fail "bash -n packages/$(basename "$f")"
        fi
    done

    for f in "$ARCHE"/themes/*.sh; do
        if bash -n "$f" 2>/dev/null; then
            pass "bash -n themes/$(basename "$f")"
        else
            fail "bash -n themes/$(basename "$f")"
        fi
    done

    section "Lint: Fish syntax"

    if ! command -v fish &>/dev/null; then
        skip "fish not installed — skipping fish syntax checks"
    else
        local fish_files
        fish_files=$(find "$ARCHE/stow/fish" -name '*.fish' -type f 2>/dev/null || true)
        if [[ -n "$fish_files" ]]; then
            while IFS= read -r f; do
                local rel="${f#$ARCHE/}"
                if fish --no-execute "$f" 2>/dev/null; then
                    pass "fish --no-execute $rel"
                else
                    fail "fish --no-execute $rel"
                fi
            done <<< "$fish_files"
        else
            skip "No fish files found"
        fi
    fi

    section "Lint: Shellcheck"

    if command -v shellcheck &>/dev/null; then
        for f in "$ARCHE"/scripts/*.sh; do
            if shellcheck -x -s bash "$f" 2>/dev/null; then
                pass "shellcheck $(basename "$f")"
            else
                fail "shellcheck $(basename "$f")"
            fi
        done
    else
        skip "shellcheck not installed"
    fi

    section "Lint: Package files — arrays only"

    for f in "$ARCHE"/packages/*.sh; do
        local name
        name="$(basename "$f")"
        # Source in subshell and check only PACMAN_PKGS and AUR_PKGS are set
        if (
            PACMAN_PKGS=()
            AUR_PKGS=()
            source "$f"
            [[ ${#PACMAN_PKGS[@]} -ge 0 && ${#AUR_PKGS[@]} -ge 0 ]]
        ); then
            pass "packages/$name declares valid arrays"
        else
            fail "packages/$name failed to source"
        fi
    done

    section "Lint: Theme variables"

    local required_vars=(
        COLOR_BG COLOR_BG_ALT COLOR_BG_SURFACE COLOR_FG COLOR_FG_MUTED
        COLOR_ACCENT COLOR_ACCENT_ALT COLOR_SUCCESS COLOR_WARN COLOR_CRITICAL COLOR_BORDER
        FONT_SANS FONT_MONO FONT_SIZE_NORMAL FONT_SIZE_SMALL FONT_SIZE_BAR
        RADIUS BORDER_SIZE GAP BAR_HEIGHT NOTIF_WIDTH NOTIF_MARGIN
    )

    for f in "$ARCHE"/themes/*.sh; do
        local name
        name="$(basename "$f")"
        local missing=0
        # Source theme and check all required vars
        (
            source "$f"
            for var in "${required_vars[@]}"; do
                if [[ -z "${!var:-}" ]]; then
                    echo "MISSING:$var"
                    exit 1
                fi
            done
        ) 2>/dev/null
        if [[ $? -eq 0 ]]; then
            pass "themes/$name exports all required variables"
        else
            fail "themes/$name missing required variables"
        fi
    done

    section "Lint: Active theme symlink"

    if [[ -L "$ARCHE/themes/active" && -f "$ARCHE/themes/active" ]]; then
        pass "themes/active symlink valid"
    elif [[ -L "$ARCHE/themes/active" ]]; then
        fail "themes/active symlink broken"
    else
        fail "themes/active not a symlink"
    fi
}

# ─── Stow Tests ───

test_stow() {
    section "Stow: Dry-run conflict check"

    if ! command -v stow &>/dev/null; then
        skip "stow not installed"
        return
    fi

    for pkg_dir in "$ARCHE"/stow/*/; do
        local pkg
        pkg="$(basename "$pkg_dir")"
        if stow -d "$ARCHE/stow" -t "$HOME" --no-folding -n "$pkg" 2>/dev/null; then
            pass "stow -n $pkg (no conflicts)"
        else
            fail "stow -n $pkg (conflicts detected)"
        fi
    done

    section "Stow: Package structure"

    for pkg_dir in "$ARCHE"/stow/*/; do
        local pkg
        pkg="$(basename "$pkg_dir")"
        # Every stow package should have at least one file
        local file_count
        file_count=$(find "$pkg_dir" -type f 2>/dev/null | wc -l)
        if [[ "$file_count" -gt 0 ]]; then
            pass "$pkg has files"
        else
            fail "$pkg is empty"
        fi
    done
}

# ─── Integration Tests ───

test_integration() {
    section "Integration: Fish loads cleanly"

    if command -v fish &>/dev/null; then
        if fish -c 'echo ok' &>/dev/null; then
            pass "fish -c 'echo ok'"
        else
            fail "fish fails to load"
        fi
    else
        skip "fish not installed"
    fi

    section "Integration: Core tools available"

    local tools=(git stow just eza bat rg fd fzf zoxide fish starship)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            pass "$tool in PATH"
        else
            skip "$tool not installed"
        fi
    done

    section "Integration: Rendered templates"

    if [[ -f "$ARCHE/themes/active" ]]; then
        # Test that theme_render can at least source the theme
        if (source "$ARCHE/themes/active" 2>/dev/null); then
            pass "active theme sources cleanly"
        else
            fail "active theme fails to source"
        fi
    else
        skip "no active theme"
    fi
}

# ─── Main ───

mode="${1:-lint}"

case "$mode" in
    lint)
        test_lint
        ;;
    stow)
        test_stow
        ;;
    integration)
        test_integration
        ;;
    all)
        test_lint
        test_stow
        test_integration
        ;;
    *)
        echo "Usage: $0 [lint|stow|integration|all]"
        exit 1
        ;;
esac

summary
