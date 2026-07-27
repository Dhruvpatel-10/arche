#!/usr/bin/env bash
# macos/clip-setup.sh — route macOS screenshots to the default server.
#
# Points the system screenshot location at a local staging directory, then
# installs a launchd agent that watches it. When a screenshot lands, the agent
# runs 'arche-clip flush', which sends the file to ~/.clip/ on the default
# server, puts the remote path on the clipboard for Maccy, and removes the local
# copy once it has landed.
#
# Nothing here needs a third-party hotkey daemon: the capture is done by the
# built-in screenshot shortcuts, and launchd does the watching.
#
# Independently runnable: bash macos/clip-setup.sh

set -euo pipefail

ARCHE="${ARCHE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ARCHE/core/lib.sh"

STAGING="$HOME/.clip"
LABEL="dev.arche.clip"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
CLIP_BIN="$HOME/.local/bin/arche/arche-clip"

[[ "$(uname -s)" == "Darwin" ]] || { log_err "This is macOS only."; exit 1; }

# ── The staging directory ──

if [[ -d "$STAGING" ]]; then
    log_warn "Staging directory already there: ${STAGING/#$HOME/~}"
else
    mkdir -p "$STAGING"
    log_ok "Created staging directory ${STAGING/#$HOME/~}"
fi

# ── Point the screenshot service at it ──
#
# This is a single global setting, so every screenshot saved to a file goes
# through the pipeline, not only the shortcuts you rebind.

current="$(defaults read com.apple.screencapture location 2>/dev/null || echo "")"
# The stored preference can hold either an expanded path or a literal "~/.clip"
# (that is how the macOS default is written), so both count as already set.
# shellcheck disable=SC2088
if [[ "$current" == "$STAGING" || "$current" == "~/.clip" ]]; then
    log_warn "Screenshots already save to ${STAGING/#$HOME/~}"
else
    [[ -n "$current" ]] && log_info "Screenshots currently save to $current — remember this if you want it back."
    defaults write com.apple.screencapture location "$STAGING"
    killall SystemUIServer 2>/dev/null || true
    log_ok "Screenshots now save to ${STAGING/#$HOME/~}"
fi

# ── The watcher ──

if [[ ! -x "$CLIP_BIN" ]]; then
    log_err "arche-clip is not at ${CLIP_BIN/#$HOME/~} — stow the arche-cli package first."
    exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$CLIP_BIN</string>
        <string>flush</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>$STAGING</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$HOME/.local/bin/arche:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>ThrottleInterval</key>
    <integer>2</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardErrorPath</key>
    <string>/tmp/arche-clip.err</string>
</dict>
</plist>
PLIST_EOF
log_ok "Wrote ${PLIST/#$HOME/~}"

launch_agent_load "$PLIST"

# ── What is left for you to do by hand ──

cat <<EOF

$(log_info "One manual step remains — macOS keyboard shortcuts cannot be set from a script.")

  Open  System Settings > Keyboard > Keyboard Shortcuts > Screenshots
  Set   "Save picture of selected area as a file"  to  Cmd+Shift+1
  Set   "Save picture of screen as a file"         to  Cmd+Shift+2

Until you do, the stock Cmd+Shift+4 and Cmd+Shift+3 drive the same pipeline.

Check it with:  arche-clip status
EOF
