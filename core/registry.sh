#!/usr/bin/env bash
# core/registry.sh — the package registry: a small "tool" DSL parser + resolver.
#
# One source of truth for every package, across platforms, so a per-platform
# provider can never drift silently again (this is what let `cask mpv` slip in).
#
# DSL — one tool per line in packages/*.reg:
#     tool <name> <platform>=<kind>:<pkg> [<platform>=<kind>:<pkg> ...]
#
#   platforms : arch, macos
#   kinds     : arch  -> pacman | aur
#               macos -> brew | cask
#
# Omit a platform where the tool does not exist there. '#' starts a comment.
#
#   tool mpv      arch=pacman:mpv          macos=brew:mpv       # never a cask
#   tool gh       arch=pacman:github-cli   macos=brew:gh        # name differs
#   tool paru     arch=aur:paru
#   tool ghostty  macos=cask:ghostty
#
# Kept bash 3.2 safe (macOS): no associative arrays, no mapfile.

# Expand one selector to .reg file path(s). A selector is a group name
# (packages/<name>.reg), a direct path to a .reg file, or empty for every group.
_registry_files() {
    local sel="${1:-}"
    if [[ -z "$sel" ]]; then
        find "$ARCHE/packages" -name '*.reg' -type f 2>/dev/null | sort
    elif [[ -f "$sel" ]]; then
        printf '%s\n' "$sel"
    elif [[ -f "$ARCHE/packages/$sel.reg" ]]; then
        printf '%s\n' "$ARCHE/packages/$sel.reg"
    fi
}

# Resolve one tool for a platform. Echo "kind:pkg", or return 1 if not present.
# registry_resolve <tool> <platform> [file...]
registry_resolve() {
    local tool="$1" platform="$2"; shift 2
    local files="" sel
    if [[ $# -gt 0 ]]; then
        for sel in "$@"; do files="$files $(_registry_files "$sel")"; done
    else
        files="$(_registry_files)"
    fi
    local file line name tok
    for file in $files; do
        [[ -f "$file" ]] || continue
        while IFS= read -r line; do
            line="${line%%#*}"
            # shellcheck disable=SC2086
            set -- $line
            [[ "${1:-}" == "tool" ]] || continue
            name="${2:-}"
            [[ "$name" == "$tool" ]] || continue
            shift 2 2>/dev/null || true
            for tok in "$@"; do
                case "$tok" in
                    "$platform"=*) printf '%s\n' "${tok#*=}"; return 0 ;;
                esac
            done
        done < "$file"
    done
    return 1
}

# Echo the resolved package names for a platform from the given group(s).
# registry_packages <platform> [group...]   (no group = every group)
registry_packages() {
    local platform="$1"; shift
    local files pkgs="" g
    if [[ $# -gt 0 ]]; then
        files=""
        for g in "$@"; do files="$files $(_registry_files "$g")"; done
    else
        files="$(_registry_files)"
    fi
    local file line tok
    for file in $files; do
        [[ -f "$file" ]] || continue
        while IFS= read -r line; do
            line="${line%%#*}"
            # shellcheck disable=SC2086
            set -- $line
            [[ "${1:-}" == "tool" ]] || continue
            shift 2 2>/dev/null || true
            for tok in "$@"; do
                case "$tok" in
                    "$platform"=*) pkgs="$pkgs ${tok##*:}" ;;
                esac
            done
        done < "$file"
    done
    # shellcheck disable=SC2086
    printf '%s\n' $pkgs
}

# Install every tool that has an entry for <platform> from the given group(s),
# batched by kind so each backend runs once. No group = every group.
# registry_install <platform> [group...]
registry_install() {
    local platform="$1"; shift
    local files g
    if [[ $# -gt 0 ]]; then
        files=""
        for g in "$@"; do files="$files $(_registry_files "$g")"; done
    else
        files="$(_registry_files)"
    fi

    local kinds
    case "$platform" in
        arch)  kinds="pacman aur" ;;
        macos) kinds="brew cask" ;;
        *) log_err "registry_install: no package kinds known for platform '$platform'"; return 1 ;;
    esac

    local kind
    for kind in $kinds; do
        local pkgs="" file line tok
        for file in $files; do
            [[ -f "$file" ]] || continue
            while IFS= read -r line; do
                line="${line%%#*}"
                # shellcheck disable=SC2086
                set -- $line
                [[ "${1:-}" == "tool" ]] || continue
                shift 2 2>/dev/null || true
                for tok in "$@"; do
                    case "$tok" in
                        "$platform"="$kind":*) pkgs="$pkgs ${tok##*:}" ;;
                    esac
                done
            done < "$file"
        done
        # shellcheck disable=SC2086
        set -- $pkgs
        if [[ $# -gt 0 ]]; then
            pkg_backend "$kind" "$@"
        fi
    done
}
