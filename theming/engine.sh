#!/usr/bin/env bash
# theming/engine.sh — theme engine: apply, switch, list, validate
#
# Usage:
#   bash theming/engine.sh apply [component...]   — render templates + emit JSON + reload
#   bash theming/engine.sh switch <name>          — change active theme + apply
#   bash theming/engine.sh list                   — show available themes
#   bash theming/engine.sh validate [<name>]      — validate theme against schema
#
# Layout:
#   theming/themes/<name>.sh    — value sets
#   theming/themes/schema.sh    — variable registry / contract
#   theming/themes/active       — symlink to active theme
#   theming/templates/<app>/    — per-app output specs
#       *.tmpl                  — envsubst input
#       _emit.sh                — custom emitter (replaces .tmpl rendering)
#       _reload.sh              — live-reload hook (run after render)
source "$(dirname "$0")/../scripts/lib.sh"

cmd="${1:-apply}"
shift 2>/dev/null || true

case "$cmd" in
    apply)
        theme_render "$@"
        ;;
    switch)
        theme_name="${1:?Usage: engine.sh switch <name>}"
        theme_file="$ARCHE/theming/themes/${theme_name}.sh"

        if [[ "$theme_name" == "schema" ]]; then
            log_err "schema.sh is not a theme — it defines the variable registry"
            exit 1
        fi

        if [[ ! -f "$theme_file" ]]; then
            log_err "Theme not found: $theme_file"
            log_info "Available themes:"
            for f in "$ARCHE/theming/themes"/*.sh; do
                [[ -f "$f" ]] || continue
                name="$(basename "$f" .sh)"
                [[ "$name" == "schema" ]] && continue
                echo "  $name"
            done
            exit 1
        fi

        if ! theme_validate "$theme_file"; then
            log_err "Theme '$theme_name' is invalid — not switching"
            exit 1
        fi

        ln -sfn "$theme_file" "$ARCHE/theming/themes/active"
        log_ok "Switched to theme: $theme_name"

        theme_render
        ;;
    validate)
        theme_name="${1:-}"
        if [[ -n "$theme_name" ]]; then
            theme_file="$ARCHE/theming/themes/${theme_name}.sh"
        else
            theme_file="$ARCHE/theming/themes/active"
        fi
        theme_validate "$theme_file"
        ;;
    list)
        active="$(basename "$(readlink -f "$ARCHE/theming/themes/active")" .sh 2>/dev/null || echo "none")"
        for f in "$ARCHE"/theming/themes/*.sh; do
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
        echo "Usage: engine.sh {apply|switch|list|validate} [args...]"
        exit 1
        ;;
esac
