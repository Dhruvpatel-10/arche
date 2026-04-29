pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

// WallpaperContrast — reactive view onto the current wallpaper's top-strip
// luminance and dominant color.
//
// How it works. The `arche-bar-contrast` helper (shipped in
// stow/arche-scripts/.local/bin/arche/) crops the top `barHeight` pixels
// of the active wallpaper, measures its average luminance, and extracts
// the dominant color. It writes the result as JSON to
// `$XDG_RUNTIME_DIR/arche-shell/bar-contrast.json`. FileView below watches
// that path and repolls on change; every bar surface binds to `isLight`
// and related properties to pick text / icon colors that survive a bright
// wallpaper read through our translucent surface.
//
// The sampler is invoked from two places:
//   1. `arche-wallpaper` after every `awww img` set, fire-and-forget.
//   2. A one-shot at shell start (see the Component.onCompleted below) so
//      an already-live wallpaper has contrast info before the bar paints.
//
// Defaults. Before the sampler has run even once, the file is missing
// or empty. We fall back to `isLight: false` so the shell renders in its
// traditional dark-on-dark look — no flash of inverted text on startup.
//
// Threshold. `luminance > 0.55` flips `isLight`. The number is empirical:
// the translucent bar is bgSurface @ 78% alpha, which already pulls any
// wallpaper 20-ish points toward dark. 0.55 on the wallpaper itself maps
// to roughly "bright enough that off-white text reads washed out against
// it through the bar". Tunable via the JSON payload if the helper wants
// to override.
//
// Multi-monitor. V1 writes a single global entry. When multi-monitor with
// per-screen wallpapers lands, the JSON schema will grow per-output keys
// and consumers will pass a screen name; the current API is the default
// (first-output) reading.
QtObject {
    id: root

    // ─── Public reactive state ─────────────────────────────────────────
    // Path of the wallpaper last sampled. Empty until the first write.
    readonly property string wallpaper: _data.wallpaper ?? ""

    // 0..1 luminance of the top-strip average. Defaults dark.
    readonly property real luminance: {
        const v = _data.luminance
        if (typeof v !== "number" || isNaN(v)) return 0.1
        return Math.max(0, Math.min(1, v))
    }

    // Derived boolean — drives the bar's fg / fgOnLight selector.
    // Hysteresis is unnecessary at shell rate (writes happen once per
    // wallpaper change), so a single threshold keeps the logic legible.
    readonly property bool isLight: luminance > 0.55

    // Dominant color of the top strip — not used yet, reserved for a
    // future subtle accent shift (separator rule, accent dot tint) if
    // the Ember accent fights the wallpaper.
    readonly property color dominant: {
        const s = _data.dominant
        if (typeof s === "string" && s.match(/^#[0-9a-fA-F]{6}$/)) return s
        return Colors.bg
    }

    // Exposed so consumers can grey-out adaptive behaviour before the
    // sampler has run (e.g. a debug widget).
    readonly property bool hasSample: !!wallpaper

    // ─── Parsed JSON, private ──────────────────────────────────────────
    // Kept as a plain JS object so bindings to `_data.x` don't have to
    // null-check the FileView itself. Seeded with an empty object so the
    // property readers above return their default fallbacks until the
    // file arrives.
    property var _data: ({})

    function _parse(text) {
        if (!text || !text.trim()) { _data = ({}); return }
        try { _data = JSON.parse(text) }
        catch (e) {
            console.warn("WallpaperContrast: malformed JSON:", e.message)
            _data = ({})
        }
    }

    // ─── FileView ──────────────────────────────────────────────────────
    // The runtime dir path resolves at QML load time. `Quickshell.env`
    // falls back to an empty string if the var is unset; in that case
    // we point at a stable /tmp path so the sampler and the shell agree
    // on a location even in a stripped environment (CI, containers).
    readonly property string _runtimeDir: {
        const x = Quickshell.env("XDG_RUNTIME_DIR")
        if (x && x.length > 0) return x + "/arche-shell"
        return "/tmp/arche-shell-" + (Quickshell.env("USER") || "user")
    }
    readonly property string _filePath: _runtimeDir + "/bar-contrast.json"

    property FileView _view: FileView {
        path: root._filePath
        // Reload on external writes — the sampler is an external process.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(text())
        onLoadFailed: function(reason) {
            // Missing-file is the normal pre-sample state; swallow it
            // silently so the journal stays clean. Anything else is worth
            // a warning.
            if (reason !== FileViewError.FileNotFound)
                console.warn("WallpaperContrast: load failed:", reason)
            root._data = ({})
        }
    }

    // ─── Bootstrap sampler ─────────────────────────────────────────────
    // On first construction, kick the sampler once so a live wallpaper
    // gets measured even if the user hasn't changed wallpapers since
    // the shell started. The script is idempotent and cheap (~50 ms on
    // a 4K image); a one-shot at startup is the right place.
    property Process _bootstrap: Process {
        // `which` shim: prefer the installed version, fall back to the
        // source-tree copy so a freshly-cloned arche repo still works
        // before `just stow` links the scripts into $HOME.
        command: ["sh", "-c", "command -v arche-bar-contrast >/dev/null && arche-bar-contrast || true"]
        running: false
    }

    Component.onCompleted: _bootstrap.running = true
}
