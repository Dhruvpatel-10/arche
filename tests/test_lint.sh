#!/usr/bin/env bash
# test_lint.sh — syntax, quality, and safety checks (no root, CI-safe)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.

test_lint() {

    # ── Bash syntax ──

    section "Lint: Bash syntax"

    for f in "$ARCHE"/scripts/*.sh "$ARCHE"/packages/*.sh "$ARCHE"/theming/themes/*.sh \
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

    for f in "$ARCHE"/scripts/*.sh "$ARCHE"/bootstrap.sh "$ARCHE"/install.sh; do
        [[ -f "$f" ]] || continue
        local rel="${f#$ARCHE/}"
        # lib.sh has set -euo pipefail, so sourcing it counts
        if grep -q 'set -euo pipefail' "$f" || grep -q 'source.*lib.sh' "$f"; then
            pass "$rel has strict mode or sources lib.sh"
        else
            fail "$rel missing set -euo pipefail"
        fi
    done

    # ── Shellcheck ──

    section "Lint: Shellcheck"

    if command -v shellcheck &>/dev/null; then
        for f in "$ARCHE"/scripts/*.sh "$ARCHE"/bootstrap.sh "$ARCHE"/install.sh; do
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

    # ── Package arrays ──

    section "Lint: Package files — arrays only"

    for f in "$ARCHE"/packages/*.sh; do
        local name
        name="$(basename "$f")"
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

    # ── Duplicate packages ──

    section "Lint: No duplicate packages"

    local all_pkgs
    all_pkgs=$(
        for f in "$ARCHE"/packages/*.sh; do
            (
                PACMAN_PKGS=()
                AUR_PKGS=()
                source "$f"
                printf '%s\n' "${PACMAN_PKGS[@]}" "${AUR_PKGS[@]}"
            )
        done | sort
    )
    local dupes
    dupes=$(echo "$all_pkgs" | uniq -d)
    if [[ -z "$dupes" ]]; then
        pass "No duplicate packages across registry"
    else
        fail "Duplicate packages: $dupes"
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
