pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Launcher — data layer for the app launcher picker.
//
// Enumerates .desktop applications via Quickshell.DesktopEntries and
// materializes a lean JS shape the PickerDialog can diff by id. UI
// lives in components/LauncherDialog.qml; this file knows nothing
// about geometry, keys, or widgets.
//
// ─── Lifecycle contract ────────────────────────────────────────────────
// `apps` is lazy: the .desktop parse happens on first open, not at
// shell startup. Subsequent opens reuse the cached list. Hot installs
// (pacman/paru in another terminal) trickle through `DesktopEntries`
// but are debounced 200ms so a flurry of file-watch events doesn't
// rebuild `apps` mid-keystroke (which would swap the array identity,
// force ScriptModel to do a full reset, and wipe the user's cursor).
// On close we tear everything down: stop debounce, SIGTERM in-flight
// fzf, drop pending query, silence late stdout via the generation
// counter.
//
// ─── Fuzzy matching ────────────────────────────────────────────────────
// Delegated to `fzf --filter` (hard repo dep). Each query runs fzf
// once with the app list streamed as argv lines (`sh -c 'printf
// "%s\n" "$@" | fzf …'`) — skips tempfiles and shell-quoting. Single
// process slot; concurrent requests SIGTERM the in-flight run, and
// `onExited` chases the latest pending query.
//
// ─── Stale-result defense ──────────────────────────────────────────────
// Two guards: (1) `_fzf.ranQuery` — the query this run was launched
// with; (2) `_fzf.gen` — a monotonically-increasing id incremented on
// every spawn. `onStreamFinished` applies results only when BOTH
// match the current state, so a SIGTERMed process whose EOF arrives
// after we spawned a newer one never publishes.
QtObject {
    id: root

    // ─── Public state ──────────────────────────────────────────────────
    property bool open: false

    // Lazy — empty until first show(). Thereafter kept in sync with
    // DesktopEntries changes, but only if we've already built once or
    // are currently open (so a boot-time `applicationsChanged` tick
    // doesn't drag parsing into shell startup).
    property var apps: []

    // Ranked results bound by LauncherDialog → PickerDialog. Survives
    // close so the fade-out sees the last state; repopulated on open.
    property var filtered: []

    // Spinner hint — true whenever fzf is running for a real query.
    // Consumed by LauncherDialog → PickerDialog.loading.
    readonly property bool loading: _fzf.running && _pendingQuery.length > 0

    // ─── Lifecycle ─────────────────────────────────────────────────────
    function show()   { open = true  }
    function hide()   { open = false }
    function toggle() { open = !open }

    onOpenChanged: open ? _onShow() : _onHide()

    function _onShow() {
        _ensureApps()
        filtered = apps
    }

    function _onHide() {
        // Full teardown. `onExited` for a SIGTERMed process still
        // fires _spawnFzf(); the guards there (open, pending) no-op.
        _debounce.stop()
        _pendingQuery = ""
        if (_fzf.running) _fzf.signal(15)
    }

    function _ensureApps() {
        if (apps.length > 0) return
        apps = _build(DesktopEntries.applications.values)
    }

    // Hot-install debounce — 200ms after the last DesktopEntries tick
    // we rebuild. Guarded by the lazy check: if the user has never
    // opened the launcher, skip entirely and let first show() do the
    // parse fresh.
    property Timer _rebuildDebounce: Timer {
        interval: 200
        repeat:   false
        onTriggered: {
            root.apps = root._build(DesktopEntries.applications.values)
            if (root.open && !root._pendingQuery) root.filtered = root.apps
        }
    }

    property Connections _watch: Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (root.apps.length === 0 && !root.open) return
            root._rebuildDebounce.restart()
        }
    }

    // ─── Query pipeline ────────────────────────────────────────────────
    property string _pendingQuery: ""

    function setQuery(q) {
        _pendingQuery = q
        if (!q) {
            _debounce.stop()
            filtered = apps
            if (_fzf.running) _fzf.signal(15)
            return
        }
        _debounce.restart()
    }

    property Timer _debounce: Timer {
        interval: 25
        repeat: false
        onTriggered: root._spawnFzf()
    }

    // Single-slot scheduler. If fzf is idle and there's work, start it.
    // If busy on an older query, SIGTERM and let `onExited` chase the
    // new one. If we'd just re-run the same query, no-op.
    function _spawnFzf() {
        if (!open) return
        if (!_pendingQuery) return
        if (_fzf.running) {
            if (_fzf.ranQuery !== _pendingQuery) _fzf.signal(15)
            return
        }
        if (_fzf.ranQuery === _pendingQuery) return

        const lines = new Array(apps.length)
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            lines[i] = a.id + "\t" + a.nameLower
                     + "\t" + a.keywordsLower
                     + "\t" + a.commentLower
        }

        _fzf.gen++
        _fzf.ranQuery    = _pendingQuery
        _fzf.environment = { "QUERY": _pendingQuery.toLowerCase() }
        // --nth=2,3 restricts the match surface to name + keywords.
        //   Descriptions are noise: "Manage your devices" fuzzy-matches
        //   "you" and buries YouTube under a dozen unrelated tools.
        // head -n 12 caps broad queries so the list stays scannable;
        //   fzf emits lines in score-descending order.
        _fzf.command     = [
            "sh", "-c",
            "printf '%s\\n' \"$@\" | "
                + "fzf --filter=\"$QUERY\" --delimiter='\\t' --nth=2,3 "
                + "| head -n 12",
            "sh"
        ].concat(lines)
        _fzf.running = true
    }

    property Process _fzf: Process {
        // Generation id — incremented on every spawn. Compared against
        // a captured snapshot in the stdout handler so a SIGTERMed
        // run whose EOF arrives after we spawned a newer run never
        // publishes stale results, even if the new run happens to use
        // the same query string (edge case: backspace-then-retype).
        property int gen: 0
        property string ranQuery: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // Silently drop late arrivals: after close, or for a
                // query the user has since moved past, or from a
                // generation we've already replaced.
                const stream = {
                    gen:     _fzf.gen,
                    ranQuery: _fzf.ranQuery
                }
                if (!root.open) return
                if (stream.ranQuery !== root._pendingQuery) return

                const byId = {}
                for (let i = 0; i < root.apps.length; i++)
                    byId[root.apps[i].id] = root.apps[i]

                const out  = []
                const rows = text.split("\n")
                for (let i = 0; i < rows.length; i++) {
                    const row = rows[i]
                    if (!row) continue
                    const tab = row.indexOf("\t")
                    const id  = tab >= 0 ? row.slice(0, tab) : row
                    const hit = byId[id]
                    if (hit) out.push(hit)
                }
                root.filtered = out
            }
        }

        // Whether we exited cleanly or via SIGTERM, clear `ranQuery`
        // so `_spawnFzf`'s same-query guard doesn't no-op a needed
        // re-run (edge case: user typed X, we killed the X process,
        // user still wants X — ranQuery would still say "X" and the
        // guard would skip the respawn).
        onExited: {
            _fzf.ranQuery = ""
            root._spawnFzf()
        }
    }

    // ─── Launch ────────────────────────────────────────────────────────
    function launch(app) {
        if (!app) return
        // Terminal apps: wrap with kitty. The `--` guard stops kitty
        // from eating a leading option from the target command.
        const argv = app.runInTerminal
            ? ["uwsm-app", "--", "kitty", "--"].concat(app.command)
            : ["uwsm-app", "--"].concat(app.command)
        Quickshell.execDetached(argv)
        hide()
    }

    // ─── Build ─────────────────────────────────────────────────────────
    // Dedup defensively — ScriptModel keys on `itemIdRole` for diff
    // stability but does NOT deduplicate its input; any dup in
    // DesktopEntries.applications.values would render as two visible
    // rows. Primary key is `id` (stable, fastest); secondary is an
    // argv-join fallback for the rare case where two entries share a
    // command with differing ids (seen in the wild with Flatpak +
    // host-installed versions of the same app).
    function _build(values) {
        const out = []
        if (!values) return out
        const seenId  = {}
        const seenCmd = {}
        for (let i = 0; i < values.length; i++) {
            const e = values[i]
            if (e.noDisplay) continue
            if (!e.command || e.command.length === 0) continue
            const id = e.id
            if (seenId[id]) continue
            const cmdKey = e.command.join("\u001f")
            if (seenCmd[cmdKey]) continue
            seenId[id]   = true
            seenCmd[cmdKey] = true

            const name    = e.name || id
            const comment = e.comment || e.genericName || ""
            const kw      = (e.keywords || []).join(" ")
            out.push({
                id:            id,
                name:          name,
                comment:       comment,
                icon:          e.icon || "",
                runInTerminal: e.runInTerminal,
                command:       e.command,
                nameLower:     name.toLowerCase(),
                commentLower:  comment.toLowerCase(),
                keywordsLower: kw.toLowerCase()
            })
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }

    // ─── IPC ───────────────────────────────────────────────────────────
    // Target `launcher`. Hyprland binding dispatches via
    //   qs ipc call launcher toggle
    property IpcHandler _ipc: IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show():   void { root.show() }
        function hide():   void { root.hide() }
    }
}
