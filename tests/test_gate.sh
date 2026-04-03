#!/usr/bin/env bash
# test_gate.sh — pre-install safety gate (blocks bootstrap on critical failures)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.
#
# Only checks things that would BREAK the install if wrong.
# Skips and non-critical issues are fine — the gate only blocks on hard failures.

test_gate() {

    section "Gate: Bash syntax (scripts)"

    for f in "$ARCHE"/scripts/*.sh "$ARCHE"/bootstrap.sh; do
        [[ -f "$f" ]] || continue
        local rel="${f#$ARCHE/}"
        if bash -n "$f" 2>/dev/null; then
            pass "$rel"
        else
            fail "$rel has syntax errors — would crash on run"
        fi
    done

    section "Gate: Package files parse"

    for f in "$ARCHE"/packages/*.sh; do
        local name
        name="$(basename "$f")"
        if (PACMAN_PKGS=(); AUR_PKGS=(); source "$f") 2>/dev/null; then
            pass "packages/$name"
        else
            fail "packages/$name won't source — install_group will fail"
        fi
    done

    section "Gate: Theme can render"

    if [[ ! -L "$ARCHE/themes/active" || ! -f "$ARCHE/themes/active" ]]; then
        fail "themes/active missing or broken — theme.sh will fail"
    else
        pass "themes/active symlink valid"

        # Check theme exports required vars
        local missing
        missing=$(
            source "$ARCHE/themes/schema.sh"
            source "$ARCHE/themes/active"
            for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_FONTS_REQUIRED[@]}" \
                       "${SCHEMA_INTEGERS_REQUIRED[@]}" "${SCHEMA_APPEARANCE_REQUIRED[@]}"; do
                [[ -n "${!var:-}" ]] || echo "$var"
            done
        )
        if [[ -z "$missing" ]]; then
            pass "active theme has all required variables"
        else
            fail "active theme missing: $missing — templates will render with blanks"
        fi
    fi

    section "Gate: Templates reference valid variables"

    local defined_vars
    defined_vars=$(
        source "$ARCHE/themes/schema.sh"
        for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}" \
                   "${SCHEMA_FONTS_REQUIRED[@]}" "${SCHEMA_INTEGERS_REQUIRED[@]}" \
                   "${SCHEMA_INTEGERS_OPTIONAL[@]}" "${SCHEMA_ALPHA_OPTIONAL[@]}" \
                   "${SCHEMA_APPEARANCE_REQUIRED[@]}" "${SCHEMA_APPEARANCE_INTEGERS[@]}"; do
            echo "$var"
        done
        for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
            echo "${var}_NOHASH"
            echo "${var}_RGBA"
        done
    )

    local tmpl_vars
    tmpl_vars=$(grep -roh '\${[A-Z_]*}' "$ARCHE/templates/" 2>/dev/null \
        | sort -u | sed 's/[${}]//g')

    local undefined=""
    while IFS= read -r var; do
        [[ -z "$var" ]] && continue
        if ! echo "$defined_vars" | grep -qx "$var"; then
            undefined+=" $var"
        fi
    done <<< "$tmpl_vars"

    if [[ -z "$undefined" ]]; then
        pass "all template variables defined"
    else
        fail "undefined template variables:$undefined — renders will have blanks"
    fi

    section "Gate: Stow packages won't conflict"

    if command -v stow &>/dev/null; then
        local stow_failed=false
        for pkg_dir in "$ARCHE"/stow/*/; do
            local pkg
            pkg="$(basename "$pkg_dir")"
            if ! stow -d "$ARCHE/stow" -t "$HOME" --no-folding -n "$pkg" 2>/dev/null; then
                fail "stow $pkg has conflicts — 11-stow.sh will fail"
                stow_failed=true
            fi
        done
        if [[ "$stow_failed" != true ]]; then
            pass "no stow conflicts"
        fi
    else
        skip "stow not installed yet — will be installed by 01-base.sh"
    fi

    section "Gate: Secrets"

    if [[ ! -f "$ARCHE/secrets.sh" ]]; then
        skip "secrets.sh missing — 02-security.sh will skip DNS config"
    else
        pass "secrets.sh present"
    fi
}
