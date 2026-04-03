#!/usr/bin/env bash
# theme.sh — theme engine: apply, switch, list
# Usage:
#   bash scripts/theme.sh apply [component...]   — render templates + reload
#   bash scripts/theme.sh switch <name>           — change active theme + apply
#   bash scripts/theme.sh list                    — show available themes
source "$(dirname "$0")/lib.sh"

cmd="${1:-apply}"
shift 2>/dev/null || true

case "$cmd" in
    apply)
        theme_render "$@"
        ;;
    switch)
        theme_name="${1:?Usage: theme.sh switch <name>}"
        theme_file="$ARCHE/themes/${theme_name}.sh"

        if [[ "$theme_name" == "schema" ]]; then
            log_err "schema.sh is not a theme — it defines the variable registry"
            exit 1
        fi

        if [[ ! -f "$theme_file" ]]; then
            log_err "Theme not found: $theme_file"
            log_info "Available themes:"
            for f in "$ARCHE/themes"/*.sh; do
                [[ -f "$f" ]] || continue
                name="$(basename "$f" .sh)"
                [[ "$name" == "schema" ]] && continue
                echo "  $name"
            done
            exit 1
        fi

        # Validate before switching
        if ! theme_validate "$theme_file"; then
            log_err "Theme '$theme_name' is invalid — not switching"
            exit 1
        fi

        # Update the active symlink
        ln -sfn "$theme_file" "$ARCHE/themes/active"
        log_ok "Switched to theme: $theme_name"

        # Apply all templates
        theme_render
        ;;
    validate)
        theme_name="${1:-}"
        if [[ -n "$theme_name" ]]; then
            theme_file="$ARCHE/themes/${theme_name}.sh"
        else
            theme_file="$ARCHE/themes/active"
        fi
        theme_validate "$theme_file"
        ;;
    list)
        active="$(basename "$(readlink -f "$ARCHE/themes/active")" .sh 2>/dev/null || echo "none")"
        for f in "$ARCHE"/themes/*.sh; do
            [[ -f "$f" ]] || continue
            name="$(basename "$f" .sh)"
            [[ "$name" == "schema" ]] && continue
            if [[ "$name" == "$active" ]]; then
                echo "* $name (active)"
            else
                echo "  $name"
            fi
        done
        ;;
    *)
        log_err "Unknown command: $cmd"
        echo "Usage: theme.sh {apply|switch|list|validate} [args...]"
        exit 1
        ;;
esac
