#!/usr/bin/env bash
# test_lint.sh — syntax, quality, and safety checks (no root, CI-safe)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.

test_lint() {

    # ── Bash syntax ──

    section "Lint: Bash syntax"

    for f in "$ARCHE"/core/*.sh "$ARCHE"/core/adapters/*.sh \
             "$ARCHE"/profiles/*/profile.sh "$ARCHE"/profiles/*/steps/*.sh \
             "$ARCHE"/theming/theme-lib.sh "$ARCHE"/theming/themes/*.sh \
             "$ARCHE"/bootstrap.sh "$ARCHE"/install.sh; do
        [[ -f "$f" ]] || continue
        local rel="${f#$ARCHE/}"
        if bash -n "$f" 2>/dev/null; then
            pass "bash -n $rel"
        else
            fail "bash -n $rel"
        fi
    done

    # ── stow/fish/ tree — D018 ──

    section "Lint: stow/fish/ syntax"

    if command -v fish &>/dev/null; then
        local fish_stow_files
        fish_stow_files=$(find "$ARCHE/stow/fish" -name '*.fish' -type f 2>/dev/null || true)
        if [[ -n "$fish_stow_files" ]]; then
            while IFS= read -r f; do
                local rel="${f#$ARCHE/}"
                if fish --no-execute "$f" 2>/dev/null; then
                    pass "fish --no-execute $rel"
                else
                    fail "fish --no-execute $rel"
                fi
            done <<< "$fish_stow_files"
        else
            skip "stow/fish/ not present"
        fi
    else
        skip "fish not installed — cannot lint stow/fish/"
    fi

    # ── Strict mode ──

    section "Lint: Scripts use strict mode"

    # Entrypoints (steps + the two top-level scripts) must be strict. The core/*.sh
    # libraries are sourced into bootstrap's strict context, so they are exempt.
    for f in "$ARCHE"/profiles/*/steps/*.sh "$ARCHE"/bootstrap.sh "$ARCHE"/install.sh; do
        [[ -f "$f" ]] || continue
        local rel="${f#$ARCHE/}"
        # steps source core/lib.sh (which is strict); bootstrap is strict; install uses set -eu.
        if grep -q 'set -euo pipefail' "$f" || grep -q 'source.*core/lib.sh' "$f" || grep -qE '^set -eu' "$f"; then
            pass "$rel has strict mode or sources the core"
        else
            fail "$rel missing strict mode"
        fi
    done

    # ── Shellcheck ──

    section "Lint: Shellcheck"

    if command -v shellcheck &>/dev/null; then
        for f in "$ARCHE"/core/*.sh "$ARCHE"/core/adapters/*.sh \
                 "$ARCHE"/profiles/*/profile.sh "$ARCHE"/profiles/*/steps/*.sh \
                 "$ARCHE"/bootstrap.sh "$ARCHE"/install.sh; do
            [[ -f "$f" ]] || continue
            local rel="${f#$ARCHE/}"
            if shellcheck -x -s bash "$f" 2>/dev/null; then
                pass "shellcheck $rel"
            else
                fail "shellcheck $rel"
            fi
        done
    else
        skip "shellcheck not installed"
    fi

    # ── Package registry (tool DSL) ──

    section "Lint: Package registry is well-formed"

    local reg_bad=""
    for rf in "$ARCHE"/packages/*.reg; do
        [[ -f "$rf" ]] || continue
        local rfname; rfname="$(basename "$rf")"
        while IFS= read -r line; do
            line="${line%%#*}"
            [[ -z "${line// /}" ]] && continue
            # shellcheck disable=SC2086
            set -- $line
            if [[ "${1:-}" != "tool" || -z "${2:-}" ]]; then
                reg_bad+=" [$rfname: '$line']"; continue
            fi
            shift 2
            local tok
            for tok in "$@"; do
                case "$tok" in
                    arch=pacman:*|arch=aur:*|macos=brew:*|macos=cask:*) : ;;
                    *) reg_bad+=" [$rfname: bad token '$tok']" ;;
                esac
            done
        done < "$rf"
    done
    if [[ -z "$reg_bad" ]]; then
        pass "All registry lines are well-formed"
    else
        fail "Registry problems:$reg_bad"
    fi

    # ── No duplicate tool names ──

    section "Lint: No duplicate registry tools"

    local dupe_tools
    dupe_tools=$(grep -hE '^[[:space:]]*tool[[:space:]]' "$ARCHE"/packages/*.reg 2>/dev/null \
        | awk '{print $2}' | sort | uniq -d)
    if [[ -z "$dupe_tools" ]]; then
        pass "No duplicate tool names in the registry"
    else
        fail "Duplicate tool names: $dupe_tools"
    fi

    # ── mpv must be a formula on macOS, never a cask (the drift we are guarding against) ──

    section "Lint: mpv is a Homebrew formula on macOS"

    if grep -hE '^[[:space:]]*tool[[:space:]]+mpv[[:space:]]' "$ARCHE"/packages/*.reg 2>/dev/null | grep -q 'macos=cask:'; then
        fail "mpv is declared as a cask — it must be macos=brew:mpv (the cask is deprecated/Gatekeeper-blocked)"
    else
        pass "mpv is not a cask"
    fi

    # ── Known package conflicts (e.g. tealdeer vs tldr on /usr/bin/tldr) ──

    section "Lint: No known conflicting packages"

    if grep -hE '(pacman|brew):tldr([[:space:]]|$)' "$ARCHE"/packages/*.reg 2>/dev/null | grep -q .; then
        fail "The 'tldr' package is present — it conflicts with tealdeer on /usr/bin/tldr"
    else
        pass "No tealdeer/tldr conflict"
    fi

    # ── Theme validation (schema-driven) ──

    section "Lint: Theme variables (schema-driven)"

    for f in "$ARCHE"/theming/themes/*.sh; do
        local name
        name="$(basename "$f")"
        [[ "$name" == "schema.sh" ]] && continue

        local missing
        missing=$(
            source "$ARCHE/theming/themes/schema.sh"
            source "$f"
            for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_FONTS_REQUIRED[@]}" \
                       "${SCHEMA_INTEGERS_REQUIRED[@]}" "${SCHEMA_APPEARANCE_REQUIRED[@]}"; do
                [[ -n "${!var:-}" ]] || echo "$var"
            done
        )
        if [[ -z "$missing" ]]; then
            pass "theming/themes/$name exports all required variables"
        else
            fail "theming/themes/$name missing: $missing"
        fi
    done

    # ── Active theme symlink ──

    section "Lint: Active theme symlink"

    if [[ -L "$ARCHE/theming/themes/active" && -f "$ARCHE/theming/themes/active" ]]; then
        pass "theming/themes/active symlink valid"
    elif [[ -L "$ARCHE/theming/themes/active" ]]; then
        fail "theming/themes/active symlink broken"
    else
        fail "theming/themes/active not a symlink"
    fi

    # ── Template variable coverage ──

    section "Lint: Template variables defined"

    local defined_vars
    defined_vars=$(
        source "$ARCHE/theming/themes/schema.sh"
        for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}" \
                   "${SCHEMA_FONTS_REQUIRED[@]}" "${SCHEMA_INTEGERS_REQUIRED[@]}" \
                   "${SCHEMA_INTEGERS_OPTIONAL[@]}" "${SCHEMA_ALPHA_OPTIONAL[@]}" \
                   "${SCHEMA_OPACITY_OPTIONAL[@]}" \
                   "${SCHEMA_APPEARANCE_REQUIRED[@]}" "${SCHEMA_APPEARANCE_INTEGERS[@]}"; do
            echo "$var"
        done
        for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
            echo "${var}_NOHASH"
            echo "${var}_RGBA"
            echo "${var}_RGB"
            echo "${var}_BGR"
        done
        # System env vars theme_render explicitly passes through envsubst
        echo "HOME"
    )

    local tmpl_vars
    tmpl_vars=$(grep -roh '\${[A-Z_]*}' "$ARCHE/theming/templates/" 2>/dev/null \
        | sort -u | sed 's/[${}]//g')

    local undefined=""
    while IFS= read -r var; do
        [[ -z "$var" ]] && continue
        if ! echo "$defined_vars" | grep -qx "$var"; then
            undefined+=" $var"
        fi
    done <<< "$tmpl_vars"

    if [[ -z "$undefined" ]]; then
        pass "All template variables defined in schema"
    else
        fail "Undefined template variables:$undefined"
    fi

    # ── Secrets safety ──

    section "Lint: Secrets safety"

    if grep -qx 'secrets.sh' "$ARCHE/.gitignore" 2>/dev/null; then
        pass "secrets.sh in .gitignore"
    else
        fail "secrets.sh NOT in .gitignore"
    fi

    local tracked_secrets
    tracked_secrets=$(git -C "$ARCHE" grep -lE '\b[0-9a-f]{6,}\.dns\.nextdns\.io' -- ':!secrets.sh*' 2>/dev/null || true)
    if [[ -z "$tracked_secrets" ]]; then
        pass "No NextDNS IDs in tracked files"
    else
        fail "Possible secret in tracked files: $tracked_secrets"
    fi

    if [[ -f "$ARCHE/secrets.sh.example" ]]; then
        pass "secrets.sh.example exists"
    else
        fail "secrets.sh.example missing"
    fi
}
