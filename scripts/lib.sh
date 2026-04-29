#!/usr/bin/env bash
# lib.sh — shared primitives for all arche scripts
# Usage: source "$(dirname "$0")/lib.sh"

set -euo pipefail

ARCHE="${ARCHE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── Secrets ───

[[ -f "$ARCHE/secrets.sh" ]] && source "$ARCHE/secrets.sh"

# ─── Logging ───

# File logging — call log_init to start capturing all output to a file.
# Safe to call multiple times; only the first call takes effect.
ARCHE_LOG_FILE=""

log_init() {
    [[ -n "$ARCHE_LOG_FILE" ]] && return 0
    local log_dir="$ARCHE/logs"
    mkdir -p "$log_dir"
    ARCHE_LOG_FILE="$log_dir/$(date +%Y%m%d-%H%M%S).log"
    # Tee stdout+stderr to log file while preserving terminal output.
    # Strip ANSI codes in the log file for clean reading.
    exec > >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$ARCHE_LOG_FILE"))
    exec 2> >(tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$ARCHE_LOG_FILE") >&2)
    export ARCHE_LOG_FILE
}

log_info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
log_ok()      { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
log_warn()    { printf '\033[1;33m[~]\033[0m %s\n' "$*"; }
log_err()     { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; }
log_section() { printf '\n\033[1;36m── %s ──\033[0m\n\n' "$*"; }

# ─── System File Linking ───

link_system_file() {
    local src="$1" dst="$2"

    if [[ ! -f "$src" ]]; then
        log_err "Source not found: $src"
        return 1
    fi

    # Resolve to the canonical path so the installed symlink targets
    # /opt/arche/… directly, not a per-user /home/<user>/arche symlink
    # (home dirs are mode 700 — services like sddm can't traverse them).
    src="$(readlink -f "$src")"

    # If an existing link's *literal* target goes through /home/, it's stale
    # (installed from a ~/arche clone before this was fixed) — force recreate.
    if [[ -L "$dst" ]]; then
        local literal
        literal="$(readlink "$dst")"
        if [[ "$literal" == "$src" ]]; then
            log_warn "Already linked: $dst"
            return 0
        fi
        if [[ "$literal" == /home/* ]]; then
            log_info "Repointing stale symlink via /home/: $dst"
            sudo rm -f "$dst"
        fi
    fi

    if [[ -f "$dst" && ! -L "$dst" ]]; then
        sudo cp "$dst" "${dst}.bak"
        log_info "Backed up original: ${dst}.bak"
    fi

    sudo mkdir -p "$(dirname "$dst")"
    sudo ln -sf "$src" "$dst"
    log_ok "Linked: $dst"
}

# Walk system/ tree and symlink every file to its / counterpart.
# system/etc/pacman.conf → /etc/pacman.conf
# system/usr/local/bin/foo → /usr/local/bin/foo (made executable)
# Symlinks in system/ (e.g. to tools/bin/*) are preserved as-is so that
# /usr/local/bin/arche/X → /opt/arche/system/usr/local/bin/arche/X → tools/bin/X.
link_system_all() {
    local sys_dir="$ARCHE/system"

    if [[ ! -d "$sys_dir" ]]; then
        log_err "system/ directory not found"
        return 1
    fi

    while IFS= read -r -d '' src; do
        local rel="${src#"$sys_dir"}"
        link_system_file "$src" "$rel"
        # Make scripts executable (follows symlinks — chmod on final target)
        if [[ "$rel" == /usr/local/bin/* ]]; then
            sudo chmod +x "$rel"
        fi
    done < <(find "$sys_dir" \( -type f -o -type l \) -print0)
}

# ─── Package Installation ───

pkg_install() {
    local pkg
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_warn "$pkg already installed"
        else
            log_info "Installing $pkg..."
            sudo pacman -S --needed "$pkg"
        fi
    done
}

aur_install() {
    local aur_helper=""
    if command -v paru &>/dev/null; then
        aur_helper="paru"
    elif command -v yay &>/dev/null; then
        aur_helper="yay"
    else
        log_err "No AUR helper found (paru or yay) — install one first"
        return 1
    fi

    local pkg
    for pkg in "$@"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            log_warn "$pkg already installed"
        else
            log_info "Installing $pkg from AUR via $aur_helper..."
            log_info "PKGBUILD: https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=$pkg"
            "$aur_helper" -S --needed "$pkg"
        fi
    done
}

install_group() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_err "Package file not found: $file"
        return 1
    fi

    # Reset arrays before sourcing
    PACMAN_PKGS=()
    AUR_PKGS=()

    # shellcheck source=/dev/null
    source "$file"

    if [[ ${#PACMAN_PKGS[@]} -gt 0 ]]; then
        log_info "Installing pacman packages from $(basename "$file")..."
        pkg_install "${PACMAN_PKGS[@]}"
    fi

    if [[ ${#AUR_PKGS[@]} -gt 0 ]]; then
        log_info "Installing AUR packages from $(basename "$file")..."
        aur_install "${AUR_PKGS[@]}"
    fi
}

# ─── GNU Stow ───

stow_pkg() {
    local pkg="$1"
    local stow_dir="$ARCHE/stow"

    if [[ ! -d "$stow_dir/$pkg" ]]; then
        log_err "Stow package not found: $stow_dir/$pkg"
        return 1
    fi

    # Clean broken symlinks in target paths before stowing
    while IFS= read -r -d '' target; do
        local rel="${target#"$stow_dir"/"$pkg"/}"
        local dest="$HOME/$rel"
        if [[ -L "$dest" && ! -e "$dest" ]]; then
            rm -f "$dest"
            log_info "Removed broken symlink: $dest"
        fi
    done < <(find "$stow_dir/$pkg" -type f -print0)

    # Dry-run to check for conflicts
    if ! stow -d "$stow_dir" -t "$HOME" --no-folding -n "$pkg" 2>/dev/null; then
        log_warn "Stow conflict for $pkg — backing up and replacing"
        # Find conflicting files and move them aside
        while IFS= read -r -d '' src; do
            local rel="${src#"$stow_dir"/"$pkg"/}"
            local dest="$HOME/$rel"
            if [[ -e "$dest" && ! -L "$dest" ]]; then
                mv "$dest" "${dest}.pre-stow"
                log_info "Backed up: $rel"
            elif [[ -L "$dest" ]]; then
                rm -f "$dest"
            fi
        done < <(find "$stow_dir/$pkg" -type f -print0)
        # Now stow should work cleanly
        stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg"
        log_ok "Stowed $pkg (conflicts backed up with .pre-stow suffix)"
        return 0
    fi

    stow -d "$stow_dir" -t "$HOME" --no-folding "$pkg"
    log_ok "Stowed $pkg"
}

# ─── Systemd Services ───

svc_enable() {
    local user_flag=""
    if [[ "${1:-}" == "--user" ]]; then
        user_flag="--user"
        shift
    fi

    local svc="$1"

    if systemctl ${user_flag:+"$user_flag"} is-active --quiet "$svc" 2>/dev/null; then
        log_warn "$svc already active"
    else
        log_info "Enabling $svc..."
        systemctl ${user_flag:+"$user_flag"} enable --now "$svc"
        log_ok "$svc enabled and started"
    fi
}

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
