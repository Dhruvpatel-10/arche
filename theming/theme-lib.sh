#!/usr/bin/env bash
# theming/theme-lib.sh — portable theme validation + rendering.
#
# Extracted from the old scripts/lib.sh unchanged. Sourced by core/lib.sh so
# every profile can render themes, and by theming/engine.sh directly. The only
# OS-touching code is _theme_apply_gsettings, which self-guards to a no-op when
# gsettings or a DBus session is absent (so it is inert on macOS).

# ─── Theme Validation ───

theme_validate() {
    local theme_file="${1:-$ARCHE/theming/themes/active}"

    if [[ ! -f "$theme_file" ]]; then
        log_err "Theme file not found: $theme_file"
        return 1
    fi

    # shellcheck source=/dev/null
    source "$ARCHE/theming/themes/schema.sh"
    # shellcheck source=/dev/null
    source "$theme_file"

    local fail=0 var

    # Required colors — must be set and match #hex6
    for var in "${SCHEMA_COLORS_REQUIRED[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_err "Missing required color: $var"
            fail=1
        elif [[ ! "${!var}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
            log_err "$var: invalid hex '${!var}' (expected #rrggbb)"
            fail=1
        fi
    done

    # Optional colors — if set, must match #hex6
    for var in "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" && ! "${!var}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
            log_err "$var: invalid hex '${!var}' (expected #rrggbb)"
            fail=1
        fi
    done

    # Required fonts — must be non-empty
    for var in "${SCHEMA_FONTS_REQUIRED[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_err "Missing required font: $var"
            fail=1
        fi
    done

    # Required integers — must be set and numeric
    for var in "${SCHEMA_INTEGERS_REQUIRED[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_err "Missing required integer: $var"
            fail=1
        elif [[ ! "${!var}" =~ ^[0-9]+$ ]]; then
            log_err "$var: not an integer '${!var}'"
            fail=1
        fi
    done

    # Optional integers — if set, must be numeric
    for var in "${SCHEMA_INTEGERS_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" && ! "${!var}" =~ ^[0-9]+$ ]]; then
            log_err "$var: not an integer '${!var}'"
            fail=1
        fi
    done

    # Required appearance — must be non-empty strings
    for var in "${SCHEMA_APPEARANCE_REQUIRED[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_err "Missing required appearance var: $var"
            fail=1
        fi
    done

    # Appearance integers — must be numeric
    for var in "${SCHEMA_APPEARANCE_INTEGERS[@]}"; do
        if [[ -n "${!var:-}" && ! "${!var}" =~ ^[0-9]+$ ]]; then
            log_err "$var: not an integer '${!var}'"
            fail=1
        fi
    done

    # Alpha — if set, must be 2-char hex
    for var in "${SCHEMA_ALPHA_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" && ! "${!var}" =~ ^[0-9a-fA-F]{2}$ ]]; then
            log_err "$var: invalid alpha '${!var}' (expected 2-char hex)"
            fail=1
        fi
    done

    # Opacity — if set, must be decimal 0.0–1.0
    for var in "${SCHEMA_OPACITY_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" && ! "${!var}" =~ ^[01]\.[0-9]+$ && "${!var}" != "1.0" && "${!var}" != "0.0" ]]; then
            log_err "$var: invalid opacity '${!var}' (expected 0.0–1.0)"
            fail=1
        fi
    done

    if [[ $fail -eq 0 ]]; then
        log_ok "Theme valid: $(basename "$theme_file" .sh)"
    fi
    return $fail
}

# ─── Theme Rendering ───

theme_render() {
    local theme_file="$ARCHE/theming/themes/active"

    if [[ ! -f "$theme_file" ]]; then
        log_err "No active theme — run: theming/engine.sh switch <name>"
        return 1
    fi

    # Validate before rendering — catch broken themes early
    if ! theme_validate "$theme_file"; then
        log_err "Theme validation failed — aborting render"
        return 1
    fi

    # Load schema — defines SCHEMA_COLORS_REQUIRED, SCHEMA_COLORS_OPTIONAL, etc.
    # shellcheck source=/dev/null
    source "$ARCHE/theming/themes/schema.sh"

    # Load theme values
    # shellcheck source=/dev/null
    source "$theme_file"

    # Apply defaults for optional variables
    : "${COLOR_CURSOR:=$COLOR_FG}"
    : "${COLOR_TEAL:=$COLOR_ACCENT_ALT}"
    : "${COLOR_PINK:=$COLOR_CRITICAL}"
    : "${COLOR_MAUVE:=$COLOR_ACCENT_ALT}"
    : "${COLOR_PEACH:=$COLOR_WARN}"
    : "${COLOR_SKY:=$COLOR_ACCENT_ALT}"
    : "${COLOR_OVERLAY0:=$COLOR_FG_MUTED}"
    : "${COLOR_OVERLAY1:=$COLOR_FG_MUTED}"
    : "${COLOR_SUBTEXT1:=$COLOR_FG_MUTED}"
    : "${COLOR_CRUST:=$COLOR_BG_ALT}"
    : "${COLOR_SURFACE1:=$COLOR_BORDER}"
    : "${COLOR_SURFACE2:=$COLOR_BORDER}"
    : "${COLOR_BG_ALPHA:=D0}"
    : "${NOTIF_BG_ALPHA:=D8}"
    : "${NOTIF_WIDTH:=400}"
    : "${NOTIF_MARGIN:=12}"
    : "${NOTIF_PADDING_V:=16}"
    : "${NOTIF_PADDING_H:=20}"
    : "${NOTIF_RADIUS:=$RADIUS}"
    : "${NOTIF_BORDER_SIZE:=$BORDER_SIZE}"
    : "${NOTIF_ICON_SIZE:=36}"
    : "${NOTIF_GAP:=14}"
    : "${NOTIF_FONT_SIZE:=$FONT_SIZE_NORMAL}"
    : "${NOTIF_FONT_SIZE_SMALL:=$FONT_SIZE_SMALL}"
    : "${NOTIF_TIMEOUT:=5000}"
    : "${FONT_SIZE_TERMINAL:=$FONT_SIZE_NORMAL}"

    # Apply defaults for opacity variables
    : "${KITTY_OPACITY:=1.0}"
    : "${BAR_OPACITY:=0.62}"
    : "${TOOLTIP_OPACITY:=0.95}"

    # Apply defaults for appearance variables
    : "${CURSOR_SIZE:=24}"

    # Schema-driven export — no hardcoded variable lists
    local var
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}" \
               "${SCHEMA_FONTS_REQUIRED[@]}" \
               "${SCHEMA_INTEGERS_REQUIRED[@]}" "${SCHEMA_INTEGERS_OPTIONAL[@]}" \
               "${SCHEMA_ALPHA_OPTIONAL[@]}" "${SCHEMA_OPACITY_OPTIONAL[@]}" \
               "${SCHEMA_APPEARANCE_REQUIRED[@]}" "${SCHEMA_APPEARANCE_INTEGERS[@]}"; do
        [[ -n "${!var:-}" ]] && export "${var?}"
    done
    # Schema-driven _NOHASH generation — all color vars get a stripped variant
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        [[ -n "${!var:-}" ]] && export "${var}_NOHASH=${!var#\#}"
    done

    # Schema-driven _RGBA generation — "R, G, B" for config formats that need it (avizo, etc.)
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            local hex="${!var#\#}"
            local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
            export "${var}_RGBA=${r}, ${g}, ${b}"
        fi
    done
    # Schema-driven _RGB generation — "R,G,B" for KDE .colors and similar INI formats
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            local hex="${!var#\#}"
            local r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
            export "${var}_RGB=${r},${g},${b}"
        fi
    done

    # Build explicit envsubst variable list — only substitute theme vars, not app vars
    local _envsubst_vars=""
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}" \
               "${SCHEMA_FONTS_REQUIRED[@]}" \
               "${SCHEMA_INTEGERS_REQUIRED[@]}" "${SCHEMA_INTEGERS_OPTIONAL[@]}" \
               "${SCHEMA_ALPHA_OPTIONAL[@]}" "${SCHEMA_OPACITY_OPTIONAL[@]}" \
               "${SCHEMA_APPEARANCE_REQUIRED[@]}" "${SCHEMA_APPEARANCE_INTEGERS[@]}"; do
        _envsubst_vars+=" \${$var}"
        # Also include _NOHASH and _RGBA variants for color vars
    done
    for var in "${SCHEMA_COLORS_REQUIRED[@]}" "${SCHEMA_COLORS_OPTIONAL[@]}"; do
        _envsubst_vars+=" \${${var}_NOHASH} \${${var}_RGBA} \${${var}_RGB}"
    done
    # Expand $HOME in templates that need absolute paths (qt5ct/qt6ct color_scheme_path)
    _envsubst_vars+=" \${HOME}"

    local components=("$@")

    # If no args, render every component dir under theming/templates/
    if [[ ${#components[@]} -eq 0 ]]; then
        components=()
        for tmpl_dir in "$ARCHE/theming/templates"/*/; do
            [[ -d "$tmpl_dir" ]] && components+=("$(basename "$tmpl_dir")")
        done
    fi

    # Per-component dispatch:
    #   1. If _emit.sh exists  → source it (custom emitter; e.g. arche/ writes JSON)
    #   2. Else                → envsubst every *.tmpl into ~/.config/<component>/
    #   3. If _reload.sh exists → source it (live reload hook for the app)
    # No central case statement. Add new component = drop a dir under
    # theming/templates/ with the right files. Engine doesn't need editing.
    local component tmpl output
    for component in "${components[@]}"; do
        local tmpl_dir="$ARCHE/theming/templates/$component"
        if [[ ! -d "$tmpl_dir" ]]; then
            log_warn "No templates for $component — skipping"
            continue
        fi

        if [[ -f "$tmpl_dir/_emit.sh" ]]; then
            # shellcheck source=/dev/null
            source "$tmpl_dir/_emit.sh"
        else
            while IFS= read -r -d '' tmpl; do
                # templates/kitty/theme.conf.tmpl → ~/.config/kitty/theme.conf
                local rel="${tmpl#"$tmpl_dir"/}"
                local rel_noext="${rel%.tmpl}"

                # Flat components render to ~/.config/<file> (no subdir),
                # for configs that live at top of ~/.config/ (e.g. electron-flags.conf).
                case "$component" in
                    electron-flags) output="$HOME/.config/$rel_noext" ;;
                    *)              output="$HOME/.config/$component/$rel_noext" ;;
                esac

                mkdir -p "$(dirname "$output")"
                envsubst "$_envsubst_vars" < "$tmpl" > "${output}.tmp" && mv "${output}.tmp" "$output"
                log_ok "Rendered $component/$rel_noext"
            done < <(find "$tmpl_dir" -name '*.tmpl' -type f -print0)
        fi

        if [[ -f "$tmpl_dir/_reload.sh" ]]; then
            # shellcheck source=/dev/null
            source "$tmpl_dir/_reload.sh"
        fi
    done

    # After rendering, propagate palette to gsettings-based consumers (libadwaita + xdg-portal).
    _theme_apply_gsettings
}

# Propagate theme to gsettings — libadwaita (Nautilus, Loupe) and xdg-desktop-portal
# (Electron apps) both read color-scheme from here. Idempotent.
_theme_apply_gsettings() {
    command -v gsettings &>/dev/null || return 0
    # gsettings fails silently without a DBus session (bootstrap run as root, CI, etc.)
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}${XDG_RUNTIME_DIR:-}" ]] || return 0

    local -A desired=(
        [color-scheme]="'prefer-dark'"
        [gtk-theme]="'${GTK_THEME:-Adwaita-dark}'"
        [icon-theme]="'${ICON_THEME:-Papirus-Dark}'"
        [cursor-theme]="'${CURSOR_THEME:-Adwaita}'"
        [cursor-size]="${CURSOR_SIZE:-24}"
        [font-name]="'${FONT_SANS:-Sans} ${FONT_SIZE_NORMAL:-10}'"
    )
    local key current
    for key in "${!desired[@]}"; do
        current="$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null || echo "")"
        if [[ "$current" != "${desired[$key]}" ]]; then
            gsettings set org.gnome.desktop.interface "$key" "${desired[$key]}" 2>/dev/null \
                && log_ok "gsettings $key = ${desired[$key]}"
        fi
    done
}

# Per-app reload moved to theming/templates/<app>/_reload.sh sidecars.
# Apps without a sidecar simply pick up the new theme on next launch — silent.
