#!/usr/bin/env bash
# macos/mpv-default.sh — make the Homebrew mpv CLI the default macOS opener for
# a handful of common VIDEO files. Audio is left alone (stays with Music), and
# web/streaming containers (webm, flv, ogv) and dev-ambiguous extensions
# (.ts = TypeScript!) are deliberately excluded.
#
# Why a wrapper app: `brew install mpv` (the formula) ships a CLI binary only —
# no .app bundle — so LaunchServices has nothing to register as a handler. (The
# `mpv` *cask* does ship an .app, but it's the deprecated stolendata build that
# fails Gatekeeper and is version-behind.) So we build a tiny AppleScript-backed
# mpv.app whose only job is to receive macOS open-document events and exec the
# real, themed Homebrew mpv CLI. Then `duti` points the chosen video extensions
# at that bundle.
#
# Idempotent: rebuilds the wrapper (cheap) so it always points at the current
# brew path, then re-asserts the duti defaults (no-op if already set).
#
# Run: bash macos/mpv-default.sh   (also called by macos/bootstrap.sh)
set -euo pipefail

MACOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHE="$(cd "$MACOS_DIR/.." && pwd)"
source "$ARCHE/scripts/lib.sh"

# ─── Config: the famous, unambiguous, non-web video containers we claim ───
# Add/remove here — keep it to real video formats you actually want mpv to own.
# NOT included on purpose:
#   • audio (mp3/flac/m4a/…) — those keep opening in Music
#   • web/streaming (webm, flv, ogv) — leave with the browser
#   • .ts — that's TypeScript for dev work, not MPEG transport stream
VIDEO_EXTS=(mkv mp4 m4v mov avi wmv mpg mpeg)

# ─── Guards ───

if [[ "$(uname -s)" != "Darwin" ]]; then
    log_err "macOS only — this sets LaunchServices file associations"
    exit 1
fi

MPV_BIN="$(command -v mpv || true)"
if [[ -z "$MPV_BIN" ]]; then
    log_err "mpv not found on PATH — install it first (brew install mpv)"
    exit 1
fi
MPV_BIN="$(cd "$(dirname "$MPV_BIN")" && pwd)/$(basename "$MPV_BIN")"

if ! command -v duti &>/dev/null; then
    log_err "duti not found — install it first (brew install duti)"
    exit 1
fi

BUNDLE_ID="org.arche.mpv"
APP_DIR="$HOME/Applications/mpv.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# ─── 1. Build the wrapper app bundle ───
#
# osacompile turns the AppleScript below into a proper .app that receives the
# 'odoc' Apple Event on double-click / "Open With" — a plain shell-script app
# would never see the file paths.

log_info "Building mpv wrapper app → $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$HOME/Applications"

script_src="$(mktemp -t mpv-wrapper).applescript"
cat > "$script_src" <<APPLESCRIPT
-- Launch the Homebrew mpv CLI for files opened via Finder / "Open With".
-- Each open event starts one mpv with all the selected files as a playlist.
on open theFiles
    set argv to ""
    repeat with f in theFiles
        set argv to argv & " " & quoted form of POSIX path of f
    end repeat
    do shell script "$MPV_BIN" & argv & " > /dev/null 2>&1 &"
end open

-- Double-clicking the app icon itself (no file): just open an idle window.
on run
    do shell script "$MPV_BIN --idle=once --force-window=yes > /dev/null 2>&1 &"
end run
APPLESCRIPT

osacompile -o "$APP_DIR" "$script_src"
rm -f "$script_src"

# ─── 2. Declare bundle id + which document types we handle ───
#
# CRITICAL: we claim ONLY the exact extensions in VIDEO_EXTS — no broad UTIs
# (public.movie / public.audio / public.audiovisual-content). Broad UTIs would
# make mpv a candidate for anything *conforming* to them: audio (public.audio →
# public.audiovisual-content), MPEG transport streams (.ts, which is also a dev
# TypeScript extension), etc. — exactly the files we must NOT touch. Listing
# only the extensions keeps mpv eligible for those 8 containers and nothing else.

plist="$APP_DIR/Contents/Info.plist"
pb() { /usr/libexec/PlistBuddy -c "$1" "$plist" >/dev/null; }

pb "Set :CFBundleIdentifier $BUNDLE_ID" 2>/dev/null || pb "Add :CFBundleIdentifier string $BUNDLE_ID"
pb "Set :CFBundleName mpv"              2>/dev/null || pb "Add :CFBundleName string mpv"
pb "Add :LSMinimumSystemVersion string 11.0" 2>/dev/null || true

pb "Delete :CFBundleDocumentTypes" 2>/dev/null || true
pb "Add :CFBundleDocumentTypes array"
pb "Add :CFBundleDocumentTypes:0 dict"
pb "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Video"
pb "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer"
pb "Add :CFBundleDocumentTypes:0:LSHandlerRank string Default"
pb "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array"
i=0
for ext in "${VIDEO_EXTS[@]}"; do
    pb "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:$i string $ext"
    i=$(( i + 1 ))
done

# ─── 3. Re-sign — CRITICAL ───
#
# osacompile ad-hoc-signs the app; editing Info.plist above invalidates that
# signature, and LaunchServices SILENTLY refuses to honor an app with a broken
# signature as a handler (duti returns success but nothing changes). Re-sign
# ad-hoc so the bundle is valid again, then (re)register it.
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || \
    log_warn "codesign failed — associations may not stick"

[[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$APP_DIR" || true

# ─── 4. Point the chosen video extensions at the wrapper ───

log_info "Setting mpv as default for ${#VIDEO_EXTS[@]} video formats: ${VIDEO_EXTS[*]}"
for ext in "${VIDEO_EXTS[@]}"; do
    duti -s "$BUNDLE_ID" ".$ext" all 2>/dev/null || true
done

# Verify what actually stuck (LaunchServices can be flaky for system-owned UTIs).
sleep 1
stuck=(); missed=()
for ext in "${VIDEO_EXTS[@]}"; do
    if [[ "$(duti -x "$ext" 2>/dev/null | head -1)" == "mpv" ]]; then
        stuck+=("$ext")
    else
        missed+=("$ext")
    fi
done

log_ok "mpv is now the default for: ${stuck[*]:-(none)}"
[[ ${#missed[@]} -gt 0 ]] && log_warn "Did not take (system app holds these): ${missed[*]}"
log_info "Wrapper app: $APP_DIR  →  $MPV_BIN"
log_info "Audio, web (webm/flv), and .ts are intentionally left untouched."
log_info "To undo: right-click a file → Get Info → 'Open with' → pick an app → Change All"
