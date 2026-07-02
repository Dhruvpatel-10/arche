# Emit canonical /opt/arche/run/dms-theme.json — the custom color scheme
# DankMaterialShell consumes via settings.json { currentThemeName: "custom",
# customThemeFile: "/opt/arche/run/dms-theme.json" }. See D032.
#
# Same philosophy as arche/_emit.sh: one system-shared file, every running dms
# instance (stark + leanscale) file-watches it and re-paints on theme switch.
# /opt/arche is mode 2775 + users group, so any user can write here.
#
# dms theme keys are Material Design 3 roles, NOT arche's flat schema — so we
# map. Matugen is disabled (DMS_DISABLE_MATUGEN=1 in the service drop-in); dms
# uses these literal hex values verbatim. Fonts live in per-user settings.json,
# not here (dms custom themes are colors-only).
#
# Sourced by lib.sh theme_render with all schema vars exported. Atomic write.

_dms_run="$ARCHE/run"
mkdir -p "$_dms_run"
_dms_json="$_dms_run/dms-theme.json"

cat > "${_dms_json}.tmp" <<EOF
{
  "name":                    "arche-$(basename "$(readlink -f "$ARCHE/theming/themes/active")" .sh)",
  "primary":                 "${COLOR_ACCENT}",
  "primaryText":             "${COLOR_CRUST}",
  "primaryContainer":        "${COLOR_SURFACE1}",
  "secondary":               "${COLOR_ACCENT_ALT}",
  "surfaceTint":             "${COLOR_ACCENT}",
  "surface":                 "${COLOR_BG}",
  "surfaceText":             "${COLOR_FG}",
  "surfaceVariant":          "${COLOR_BG_SURFACE}",
  "surfaceVariantText":      "${COLOR_FG_MUTED}",
  "surfaceContainer":        "${COLOR_BG_SURFACE}",
  "surfaceContainerHigh":    "${COLOR_SURFACE1}",
  "surfaceContainerHighest": "${COLOR_SURFACE2}",
  "background":              "${COLOR_BG}",
  "backgroundText":          "${COLOR_FG}",
  "outline":                 "${COLOR_BORDER}",
  "error":                   "${COLOR_CRITICAL}",
  "warning":                 "${COLOR_WARN}",
  "info":                    "${COLOR_ACCENT_ALT}"
}
EOF

# 664 so the OTHER user on the host (setgid `users` group on /opt/arche/run)
# can overwrite on their next theme switch; mv -f to never block on a prompt
# when replacing a file owned by a different user.
chmod 664 "${_dms_json}.tmp"
mv -f "${_dms_json}.tmp" "$_dms_json"
log_ok "Emitted /opt/arche/run/dms-theme.json"
unset _dms_json _dms_run
