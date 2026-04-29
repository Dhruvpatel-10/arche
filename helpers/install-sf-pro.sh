#!/usr/bin/env bash
# install-sf-pro.sh — fetch + install Apple SF Pro fonts to /usr/share/fonts/SF-Pro
#
# Apple's SF Pro is free-for-design under Apple's font license — fine for
# personal UI rendering. Fetched from the public Apple developer CDN.
#
# Usage:
#   bash helpers/install-sf-pro.sh                # auto-download dmg (~213MB)
#   bash helpers/install-sf-pro.sh /path/SF-Pro.dmg  # use local dmg

set -euo pipefail
source "$(dirname "$0")/../scripts/lib.sh"

DMG_URL="https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg"
DEST="/usr/share/fonts/SF-Pro"
LOCAL_DMG="${1:-}"

if [[ -d "$DEST" ]] && compgen -G "$DEST/*.otf" >/dev/null; then
    log_warn "SF Pro already installed → $DEST"
    log_info "Remove $DEST and re-run to reinstall"
    exit 0
fi

for tool in 7z bsdtar curl; do
    if ! command -v "$tool" &>/dev/null; then
        log_err "$tool required (sudo pacman -S 7zip libarchive curl)"
        exit 1
    fi
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. Acquire dmg
if [[ -n "$LOCAL_DMG" ]]; then
    [[ -f "$LOCAL_DMG" ]] || { log_err "Not found: $LOCAL_DMG"; exit 1; }
    log_info "Using local dmg: $LOCAL_DMG"
    cp "$LOCAL_DMG" "$tmp/sf.dmg"
else
    log_info "Downloading SF-Pro.dmg from Apple (~213MB)..."
    curl -fL --progress-bar "$DMG_URL" -o "$tmp/sf.dmg"
fi

# 2. Extract dmg → finds .pkg
log_info "Extracting dmg..."
7z x -y -o"$tmp/d1" "$tmp/sf.dmg" >/dev/null

pkg=$(find "$tmp/d1" -name "*.pkg" -type f 2>/dev/null | head -1)
[[ -z "$pkg" ]] && { log_err "No .pkg found inside dmg"; exit 1; }

# 3. Extract pkg (xar) → finds Payload(s)
log_info "Extracting pkg: $(basename "$pkg")..."
7z x -y -o"$tmp/d2" "$pkg" >/dev/null

# 4. Each subpackage has a Payload (gzip-compressed cpio). Extract each in place.
log_info "Extracting payloads..."
while IFS= read -r p; do
    pdir="$(dirname "$p")"
    bsdtar -xf "$p" -C "$pdir" 2>/dev/null || true
done < <(find "$tmp/d2" -name "Payload" -type f)

# 5. Collect all .otf into one place
mkdir -p "$tmp/otfs"
find "$tmp/d2" -name "*.otf" -type f -exec cp {} "$tmp/otfs/" \;

count=$(find "$tmp/otfs" -maxdepth 1 -name "*.otf" | wc -l)
[[ "$count" -eq 0 ]] && { log_err "No .otf files extracted from pkg"; exit 1; }

# 6. Install
sudo mkdir -p "$DEST"
sudo cp "$tmp/otfs"/*.otf "$DEST/"
sudo fc-cache -f "$DEST"

log_ok "Installed $count SF Pro font files → $DEST"
log_info "Family names installed:"
fc-list : family | grep -iE "^SF Pro" | sort -u || true
log_info "Run 'just theme-apply' to re-render configs that reference SF Pro"
