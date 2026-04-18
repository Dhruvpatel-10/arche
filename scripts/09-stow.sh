#!/usr/bin/env bash
# 09-stow.sh — stow all remaining packages
source "$(dirname "$0")/lib.sh"

log_info "Stowing all packages..."

stow_dir="$ARCHE/stow"

for pkg_dir in "$stow_dir"/*/; do
    [[ -d "$pkg_dir" ]] || continue
    pkg="$(basename "$pkg_dir")"

    # Skip empty packages
    file_count=$(find "$pkg_dir" -type f | wc -l)
    if [[ "$file_count" -eq 0 ]]; then
        log_warn "Skipping empty stow package: $pkg"
        continue
    fi

    stow_pkg "$pkg"
done

log_ok "All stow packages linked"
