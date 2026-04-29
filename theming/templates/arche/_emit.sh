# Emit canonical /opt/arche/run/theme.json for arche-owned consumers
# (quickshell panel, future arche TUI/CLI tools). Single source of truth
# in machine-readable form — file is watched via FileView for hot-reload.
#
# Path is system-shared (not per-user) so any user switching themes
# updates every running panel on the host. /opt/arche is mode 2775 with
# the users group, so any member of users can write here. See D014 + D029.
#
# Sourced by lib.sh theme_render with all schema vars exported. Atomic
# write via tmp + mv so concurrent FileView reads can never see a torn
# half-written file.

_arche_run="$ARCHE/run"
mkdir -p "$_arche_run"
_arche_json="$_arche_run/theme.json"

cat > "${_arche_json}.tmp" <<EOF
{
  "color": {
    "bg":         "${COLOR_BG}",
    "bgAlt":      "${COLOR_BG_ALT}",
    "bgSurface":  "${COLOR_BG_SURFACE}",
    "fg":         "${COLOR_FG}",
    "fgMuted":    "${COLOR_FG_MUTED}",
    "accent":     "${COLOR_ACCENT}",
    "accentAlt":  "${COLOR_ACCENT_ALT}",
    "success":    "${COLOR_SUCCESS}",
    "warn":       "${COLOR_WARN}",
    "critical":   "${COLOR_CRITICAL}",
    "border":     "${COLOR_BORDER}",
    "cursor":     "${COLOR_CURSOR}",
    "teal":       "${COLOR_TEAL}",
    "pink":       "${COLOR_PINK}",
    "mauve":      "${COLOR_MAUVE}",
    "peach":      "${COLOR_PEACH}",
    "sky":        "${COLOR_SKY}",
    "overlay0":   "${COLOR_OVERLAY0}",
    "overlay1":   "${COLOR_OVERLAY1}",
    "subtext1":   "${COLOR_SUBTEXT1}",
    "crust":      "${COLOR_CRUST}",
    "surface1":   "${COLOR_SURFACE1}",
    "surface2":   "${COLOR_SURFACE2}"
  },
  "font": {
    "sans":       "${FONT_SANS}",
    "mono":       "${FONT_MONO}",
    "sizeNormal": ${FONT_SIZE_NORMAL},
    "sizeSmall":  ${FONT_SIZE_SMALL},
    "sizeBar":    ${FONT_SIZE_BAR}
  },
  "layout": {
    "radius":     ${RADIUS},
    "borderSize": ${BORDER_SIZE},
    "gap":        ${GAP},
    "barHeight":  ${BAR_HEIGHT}
  },
  "appearance": {
    "cursorTheme": "${CURSOR_THEME}",
    "cursorSize":  ${CURSOR_SIZE},
    "iconTheme":   "${ICON_THEME}",
    "gtkTheme":    "${GTK_THEME}"
  }
}
EOF

mv "${_arche_json}.tmp" "$_arche_json"
log_ok "Emitted /opt/arche/run/theme.json"
unset _arche_json _arche_run
