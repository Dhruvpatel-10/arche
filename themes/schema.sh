# schema.sh — single source of truth for theme variable names, types, and defaults.
# Every theme must satisfy the REQUIRED arrays. OPTIONAL vars fall back to defaults.
# Array membership IS the type: COLORS must be #hex6, INTEGERS must be numeric.
# See docs/theme-standard.md for full spec.

# ─── Color variables (value must match: #[0-9a-fA-F]{6}) ───

SCHEMA_COLORS_REQUIRED=(
    COLOR_BG              # Base background
    COLOR_BG_ALT          # Mantle / darker panels
    COLOR_BG_SURFACE      # Surface0 / raised elements
    COLOR_FG              # Primary text
    COLOR_FG_MUTED        # Secondary text / subtext0
    COLOR_ACCENT          # Primary accent
    COLOR_ACCENT_ALT      # Secondary accent
    COLOR_SUCCESS         # Positive state
    COLOR_WARN            # Warning state
    COLOR_CRITICAL        # Error / danger state
    COLOR_BORDER          # Borders and dividers
)

SCHEMA_COLORS_OPTIONAL=(
    COLOR_CURSOR          # Cursor color (default: COLOR_FG)
    COLOR_TEAL            # (default: COLOR_ACCENT_ALT)
    COLOR_PINK            # (default: COLOR_CRITICAL)
    COLOR_MAUVE           # (default: COLOR_ACCENT_ALT)
    COLOR_PEACH           # (default: COLOR_WARN)
    COLOR_SKY             # (default: COLOR_ACCENT_ALT)
    COLOR_OVERLAY0        # (default: COLOR_FG_MUTED)
    COLOR_OVERLAY1        # (default: COLOR_FG_MUTED)
    COLOR_SUBTEXT1        # (default: COLOR_FG_MUTED)
    COLOR_CRUST           # (default: COLOR_BG_ALT)
    COLOR_SURFACE1        # (default: COLOR_BORDER)
    COLOR_SURFACE2        # (default: COLOR_BORDER)
)

# ─── Font variables (value: non-empty string) ───

SCHEMA_FONTS_REQUIRED=(
    FONT_SANS             # UI / body font
    FONT_MONO             # Code / terminal font
)

# ─── Integer variables (value: non-negative integer) ───

SCHEMA_INTEGERS_REQUIRED=(
    FONT_SIZE_NORMAL      # Default font size (px/pt)
    FONT_SIZE_SMALL       # Small text
    FONT_SIZE_BAR         # Status bar text
    RADIUS                # Default border-radius (px)
    BORDER_SIZE           # Default border width (px)
    GAP                   # Window/element gap (px)
    BAR_HEIGHT            # Status bar height (px)
)

SCHEMA_INTEGERS_OPTIONAL=(
    NOTIF_WIDTH           # (default: 400)
    NOTIF_MARGIN          # (default: 12)
    NOTIF_PADDING_V       # (default: 16)
    NOTIF_PADDING_H       # (default: 20)
    NOTIF_RADIUS          # (default: RADIUS)
    NOTIF_BORDER_SIZE     # (default: BORDER_SIZE)
    NOTIF_ICON_SIZE       # (default: 36)
    NOTIF_GAP             # (default: 14)
    NOTIF_FONT_SIZE       # (default: FONT_SIZE_NORMAL)
    NOTIF_FONT_SIZE_SMALL # (default: FONT_SIZE_SMALL)
    NOTIF_TIMEOUT         # (default: 5000)
)

# ─── Special variables (value: 2-char hex alpha suffix, no #) ───

SCHEMA_ALPHA_OPTIONAL=(
    COLOR_BG_ALPHA        # Alpha suffix for rgba (default: D0)
)

# ─── Appearance variables (value: non-empty string) ───

SCHEMA_APPEARANCE_REQUIRED=(
    CURSOR_THEME          # Cursor theme name (must be installed in /usr/share/icons/)
    ICON_THEME            # Icon theme name (must be installed in /usr/share/icons/)
    GTK_THEME             # GTK theme name (e.g. Adwaita-dark)
)

SCHEMA_APPEARANCE_INTEGERS=(
    CURSOR_SIZE           # Cursor size in px (default: 24)
)
