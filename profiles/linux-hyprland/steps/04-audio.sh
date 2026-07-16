#!/usr/bin/env bash
# 04-audio.sh — PipeWire audio stack
ARCHE="${ARCHE:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export ARCHE
source "$ARCHE/core/lib.sh"

log_info "Setting up audio..."
registry_install arch audio

# Enable PipeWire user services
svc_enable --user pipewire
svc_enable --user pipewire-pulse
svc_enable --user wireplumber

# Verify
if pactl info &>/dev/null 2>&1; then
    log_ok "PipeWire audio working"
else
    log_warn "PipeWire not responding — may need relogin"
fi

log_ok "Audio setup done"
