#!/usr/bin/env bash
# 13-dms.sh — DankMaterialShell desktop shell (replaces /opt/arche/shell/).
# Installs dms, links the service drop-in + resume hook, emits the arche
# custom theme, seeds per-user settings, enables the user service. See D032.
#
# Per-user by design (like 07-panel.sh): run once per human user. The autostart
# swap (quickshell → dms) lives in stow/hypr/.config/hypr/autostart.conf and is
# applied by `just stow`. Independently runnable: `bash scripts/13-dms.sh`.
ARCHE="${ARCHE:-$(cd "$(dirname "$0")/../../.." && pwd)}"
export ARCHE
source "$ARCHE/core/lib.sh"

log_info "Setting up DankMaterialShell (dms)..."
registry_install arch dms

# ─── System links: service drop-in (matugen/polkit off) + resume hook ───
# These are also covered by link_system_all in 00-preflight; linked here too
# so this script stands alone.
link_system_file \
    "$ARCHE/system/etc/systemd/user/dms.service.d/arche.conf" \
    "/etc/systemd/user/dms.service.d/arche.conf"
link_system_file \
    "$ARCHE/system/usr/lib/systemd/system-sleep/dms-restart" \
    "/usr/lib/systemd/system-sleep/dms-restart"

# ─── Emit the arche custom theme dms consumes ───
# Writes /opt/arche/run/dms-theme.json from the active theme. Exports FONT_SANS
# / FONT_MONO into this shell for the settings seed below.
theme_render dms

# ─── Seed per-user settings.json (writable; don't clobber user changes) ───
settings="$HOME/.config/DankMaterialShell/settings.json"
mkdir -p "$(dirname "$settings")"
if [[ -f "$settings" ]]; then
    log_warn "settings.json exists — leaving user settings untouched"
else
    cat > "$settings" <<EOF
{
  "currentThemeName": "custom",
  "customThemeFile": "/opt/arche/run/dms-theme.json",
  "fontFamily": "${FONT_SANS}",
  "monoFontFamily": "${FONT_MONO}",
  "fontWeight": 400,
  "fontScale": 1.0
}
EOF
    log_ok "Seeded $settings"
fi

# ─── Enable the user service (starts with graphical-session.target) ───
systemctl --user daemon-reload 2>/dev/null || true
if systemctl --user is-enabled --quiet dms.service 2>/dev/null; then
    log_warn "dms.service already enabled"
else
    systemctl --user enable dms.service
    log_ok "dms.service enabled — starts on next graphical session"
fi

log_ok "dms setup done"
log_info "Activate now:  systemctl --user start dms.service  (stop your old quickshell first)"
log_info "Autostart swap is in stow/hypr autostart.conf — run 'just stow' to apply for next login"
