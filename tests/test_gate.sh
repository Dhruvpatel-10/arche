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

    if [[ ! -L "$ARCHE/theming/themes/active" || ! -f "$ARCHE/theming/themes/active" ]]; then
        fail "theming/themes/active missing or broken — engine.sh will fail"
    else
        pass "theming/themes/active symlink valid"

        # Check theme exports required vars
        local missing
        missing=$(
            source "$ARCHE/theming/themes/schema.sh"
            source "$ARCHE/theming/themes/active"
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
        pass "all template variables defined"
    else
        fail "undefined template variables:$undefined — renders will have blanks"
    fi

    section "Gate: Stow packages resolvable"

    # lib.sh:stow_pkg handles conflicts by backing up existing files to
    # .pre-stow, so a plain `stow -n` conflict is NOT a fatal pre-flight
    # error. We just surface any conflicts for visibility.
    if command -v stow &>/dev/null; then
        local stow_conflicts=()
        for pkg_dir in "$ARCHE"/stow/*/; do
            local pkg
            pkg="$(basename "$pkg_dir")"
            if ! stow -d "$ARCHE/stow" -t "$HOME" --no-folding -n "$pkg" 2>/dev/null; then
                stow_conflicts+=("$pkg")
            fi
        done
        if [[ ${#stow_conflicts[@]} -eq 0 ]]; then
            pass "no stow conflicts"
        else
            pass "stow conflicts will be auto-resolved via .pre-stow backup: ${stow_conflicts[*]}"
        fi
    else
        skip "stow not installed yet — will be installed by 01-base.sh"
    fi

    section "Gate: Secrets"

    # Every key in secrets.sh.example must be present and non-empty in secrets.sh.
    # Bootstrap will halt on 02-security.sh (DNS) otherwise, so catch it early.
    if [[ ! -f "$ARCHE/secrets.sh" ]]; then
        fail "secrets.sh missing — cp secrets.sh.example secrets.sh and fill in real values"
    elif [[ ! -f "$ARCHE/secrets.sh.example" ]]; then
        fail "secrets.sh.example missing — cannot determine required keys"
    else
        local required_keys=()
        while IFS= read -r key; do
            [[ -n "$key" ]] && required_keys+=("$key")
        done < <(grep -oE '^[A-Z_][A-Z0-9_]*=' "$ARCHE/secrets.sh.example" | tr -d '=')

        local missing=() blank=()
        # shellcheck disable=SC1091
        (
            set +u
            source "$ARCHE/secrets.sh"
            for k in "${required_keys[@]}"; do
                if ! declare -p "$k" &>/dev/null; then
                    echo "MISSING $k"
                elif [[ -z "${!k}" ]]; then
                    echo "BLANK $k"
                fi
            done
        ) > /tmp/arche-secrets-gate.$$

        while read -r kind key; do
            case "$kind" in
                MISSING) missing+=("$key") ;;
                BLANK)   blank+=("$key") ;;
            esac
        done < /tmp/arche-secrets-gate.$$
        rm -f /tmp/arche-secrets-gate.$$

        if [[ ${#missing[@]} -eq 0 && ${#blank[@]} -eq 0 ]]; then
            pass "secrets.sh has all keys from secrets.sh.example (${#required_keys[@]})"
        fi
        if [[ ${#missing[@]} -gt 0 ]]; then
            fail "secrets.sh missing keys: ${missing[*]} (expected from secrets.sh.example)"
        fi
        if [[ ${#blank[@]} -gt 0 ]]; then
            fail "secrets.sh has blank values for: ${blank[*]}"
        fi
    fi

}
