pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colors — semantic palette for the arche shell. Primitive tokens (bg, fg,
// accent, …) are read from /opt/arche/run/theme.json (emitted by
// theming/templates/arche/_emit.sh on every theme apply). Path is system-
// shared so a theme switch by any user re-paints every running panel on
// the host (D014 + D029). Derived tokens (mid-tones, dialog roles, danger
// styling) compute from primitives so the whole palette tracks a
// `just theme-switch <name>` automatically.
//
// FileView watches the JSON for mtime changes — switch the theme and the
// panel re-paints without restart. Hardcoded fallbacks below match the
// Ember palette so the shell renders sanely even when theme.json is
// missing (fresh checkout pre-bootstrap, CI, malformed JSON).
//
// (Named Colors, not Palette, because QtQuick Controls already provides a
// `Palette` type that wins the name resolution.)
//
// Surface ladder (deeper → lighter on the dark theme):
//
//   bgAlt < bg < card < bgSurface == pillBg < tileBg < tileBgActive
//
// Reach for the role, not the shade:
//
//   bg            the window/panel background; rarely used as a fill
//   bgAlt         deeper than bg. Text on accent, icon inside active tile
//   card          floating card / drawer surface
//   bgSurface     raised plane under a row group or list
//   pillBg        status pill at rest (in a bar or card)
//   tileBg        toggle tile at rest
//   tileBgActive  toggle tile on hover / active
QtObject {
    id: root

    // ─── JSON store ─────────────────────────────────────────────────────
    // _data is a plain JS object so bindings to _data.color.bg don't have
    // to null-check the FileView. Seeded with {} so primitive readers fall
    // through to the baked default until the file arrives.
    property var _data: ({})

    function _parse(text) {
        if (!text || !text.trim()) { _data = ({}); return }
        try { _data = JSON.parse(text) }
        catch (e) {
            console.warn("Colors: malformed theme.json:", e.message)
            _data = ({})
        }
    }

    function _c(key, fallback) {
        const c = _data.color
        if (!c) return fallback
        const v = c[key]
        if (typeof v === "string" && v.match(/^#[0-9a-fA-F]{6}$/)) return v
        return fallback
    }

    // System-shared runtime path. Quickshell shell.qml itself is symlinked
    // from each user's ~/.config/quickshell into /opt/arche/shell (D029),
    // so reading the theme from /opt/arche/run keeps the panel as a single
    // host-level artifact — no per-user emit needed.
    readonly property string _path: "/opt/arche/run/theme.json"

    property FileView _view: FileView {
        path: root._path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(text())
        onLoadFailed: function(reason) {
            // Missing file is normal pre-bootstrap; stay quiet on that one.
            if (reason !== FileViewError.FileNotFound)
                console.warn("Colors: theme.json load failed:", reason)
            root._data = ({})
        }
    }

    // ─── Surface (primitives) ───────────────────────────────────────────
    readonly property color bg:        _c("bg",        "#13151c")
    readonly property color bgAlt:     _c("bgAlt",     "#0e1016")
    readonly property color bgSurface: _c("bgSurface", "#1d2029")

    // ─── Surface (derived mid-tones) ────────────────────────────────────
    // card sits between bg and bgSurface — drawer/dialog floor.
    readonly property color card:         Qt.lighter(bg, 1.18)
    readonly property color pillBg:       bgSurface
    readonly property color tileBg:       Qt.lighter(bgSurface, 1.13)
    readonly property color tileBgActive: Qt.lighter(bgSurface, 1.30)

    // islandInk — the living notch's fill. A hair below bgAlt so the
    // island reads as a void taken *out* of the screen rather than a card
    // floating on top. See docs/island-design.md principle 2.
    readonly property color islandInk:      Qt.darker(bgAlt, 1.20)
    readonly property color islandInkHover: Qt.darker(bg, 1.10)

    // ─── Foreground (primitives) ────────────────────────────────────────
    readonly property color fg:      _c("fg",      "#cdc8bc")
    readonly property color fgMuted: _c("fgMuted", "#817c72")

    // ─── Foreground (derived) ───────────────────────────────────────────
    readonly property color fgDim: Qt.darker(fgMuted, 1.30)

    // fgOnActive — punctuation fill for active affordances. Pure white
    // intentionally; the chroma contrast against tileBgActive signals
    // state faster than fg's warm off-white. Theme-independent.
    readonly property color fgOnActive: "#ffffff"

    // ─── Accent + state (primitives) ────────────────────────────────────
    readonly property color accent:    _c("accent",    "#c9943e")
    readonly property color accentAlt: _c("accentAlt", "#6a9fb5")
    readonly property color success:   _c("success",   "#7ab87f")
    readonly property color warn:      _c("warn",      "#d4a843")
    readonly property color critical:  _c("critical",  "#c45c5c")
    readonly property color border:    _c("border",    "#282c38")

    // ─── Adaptive bar surface ───────────────────────────────────────────
    // Driven by the bar's per-screen `opacityScale` (0 → translucent, 1 →
    // opaque). Translucent = bgSurface at 78% alpha so the wallpaper reads
    // through subtly. Opaque = a half-step brighter than bgSurface so the
    // bar has its own ground when a fullscreen window takes over the
    // workspace under it.
    readonly property color surfaceOpaque:      Qt.lighter(bgSurface, 1.10)
    readonly property color surfaceTranslucent: Qt.rgba(bgSurface.r, bgSurface.g, bgSurface.b, 0.78)

    // Light-wallpaper translucent variant — warm off-white at 78% alpha.
    // Theme-independent: intended to invert the bar against bright photos
    // regardless of which dark theme is active. Alpha matches the dark
    // variant so the motion envelope of the crossfade is identical.
    readonly property color surfaceTranslucentLight: Qt.rgba(0xf2/255.0, 0xee/255.0, 0xe2/255.0, 0.78)

    // ─── Adaptive bar foreground (light-wallpaper fallback) ──────────────
    // Theme-independent — chosen for ~AA contrast on a light wallpaper
    // through 78% alpha surface. See WallpaperContrast.qml.
    readonly property color fgOnLight:      "#0f0f12"
    readonly property color fgMutedOnLight: "#3c3a34"
    readonly property color fgDimOnLight:   "#5f5c55"

    // ─── Bar pill hover (distinct from drawer tileBgActive) ─────────────
    // Bar pills get their own hover role so drawer polish can shift
    // tileBgActive without dragging the bar's hover along.
    readonly property color pillBgHover: Qt.lighter(pillBg, 1.13)

    // ─── Workspace + separator chrome ───────────────────────────────────
    // Occupied-but-inactive tile border and pill-group vertical rule
    // share a hex today. Two named roles so future divergence is a
    // one-file edit.
    readonly property color workspaceOccupied: Qt.lighter(border, 1.20)
    readonly property color separator:         Qt.lighter(border, 1.20)

    // ─── Shadow tint ────────────────────────────────────────────────────
    // Warm-black for drop shadows under bar and dialog surfaces.
    readonly property color crust: _c("crust", "#0a0b10")

    // ─── Dialog (StyledDialog consumers) ────────────────────────────────
    // Decoupled from surfaceOpaque/Translucent intentionally: dialogs are
    // always fully opaque regardless of what the bar is doing. Aliases for
    // now — the name is the contract; divergence is a one-file change.
    readonly property color dialogScrim:   Qt.rgba(0, 0, 0, 0.45)
    readonly property color dialogSurface: card
    readonly property color dialogBorder:  border

    // Danger action styling (Confirm dialog destructive button).
    // Outlined, not filled — a filled red rectangle next to a charcoal
    // card reads as an alert banner; this is a confirmation.
    readonly property color dangerBg:     Qt.rgba(critical.r, critical.g, critical.b, 0.11)
    readonly property color dangerBorder: critical
}
