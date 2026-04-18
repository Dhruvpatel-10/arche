#!/usr/bin/env bash
# test_stow.sh — stow dry-run, structure, and path validation (no root)
# Sourced by run.sh — expects helpers.sh and $ARCHE to be set.

test_stow() {

    # ── Dry-run conflicts ──

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

    # ── Package structure ──

    section "Stow: Package structure"

    for pkg_dir in "$ARCHE"/stow/*/; do
        local pkg
        pkg="$(basename "$pkg_dir")"
        local file_count
        file_count=$(find "$pkg_dir" -type f 2>/dev/null | wc -l)
        if [[ "$file_count" -gt 0 ]]; then
            pass "$pkg has $file_count files"
        else
            fail "$pkg is empty"
        fi
    done

    # ── No symlinks inside packages ──

    section "Stow: No symlinks inside packages"

    local bad_links
    bad_links=$(find "$ARCHE/stow" -type l 2>/dev/null || true)
    if [[ -z "$bad_links" ]]; then
        pass "No symlinks inside stow packages"
    else
        fail "Symlinks found inside stow: $bad_links"
    fi

    # ── Valid target paths ──

    section "Stow: All targets under .config or .local"

    local bad_paths=0
    for pkg_dir in "$ARCHE"/stow/*/; do
        local pkg
        pkg="$(basename "$pkg_dir")"
        while IFS= read -r f; do
            local rel="${f#$pkg_dir}"
            if [[ "$rel" != .config/* && "$rel" != .local/* ]]; then
                fail "$pkg has unexpected path: $rel"
                bad_paths=$((bad_paths + 1))
            fi
        done < <(find "$pkg_dir" -type f 2>/dev/null)
    done
    if [[ $bad_paths -eq 0 ]]; then
        pass "All stow targets under .config/ or .local/"
    fi
}
