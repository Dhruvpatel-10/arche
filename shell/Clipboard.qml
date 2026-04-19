pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard — data layer for the picker surface.
//
// Owns the parsed view of `cliphist list`, on-demand decoding to a tmp
// cache (images → file, text → in-memory), and the copy/delete
// actions. Query + selection state lives in the picker base
// (PickerDialog), so this singleton is concerned only with the data —
// nothing here knows about geometry, keys, or widgets.
QtObject {
    id: root

    // ─── Public state ──────────────────────────────────────────────────
    property bool open: false

    // Parsed rows. Each entry:
    //   id            cliphist numeric id (string)
    //   preview       the raw preview line from `cliphist list`
    //   isImage       matched the binary-image preview pattern
    //   ext           image extension (png/jpg/…) or ""
    //   width/height  image dimensions or 0
    //   sizeText      e.g. "407 KiB"
    //   imagePath     tmp file path once decoded, else null
    //   decodedText   full text once decoded, else null
    property var entries: []

    // Images are decoded into $XDG_RUNTIME_DIR/arche-shell/clipboard/<id>.<ext>.
    // Runtime dir is user-specific and auto-cleaned on logout.
    readonly property string cacheDir:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/arche-shell/clipboard"

    // Hard cap on rows materialized into the picker. cliphist can hit
    // ~2k entries for heavy users; ScriptModel's O(n·m) diff starts
    // to stutter at 60fps long before then. 500 is more than anyone
    // browses visually — if you need to find something older, text
    // search is the answer, not a mile-long list.
    readonly property int _maxEntries: 500

    // ─── Lifecycle ─────────────────────────────────────────────────────
    function show()   { open = true  }
    function hide()   { open = false }
    function toggle() { open = !open }

    onOpenChanged: if (open) refresh()

    // ─── Actions ───────────────────────────────────────────────────────
    function refresh() { _list.running = true }

    function pick(entry) {
        if (!entry) return
        _copy.command = ["sh", "-c",
            "cliphist decode " + _shq(entry.id) + " | wl-copy"]
        _copy.running = true
        hide()
    }

    function remove(entry) {
        if (!entry) return
        // cliphist delete reads "<id>\t<preview>" lines from stdin and
        // removes matching rows. Awk filters the list on exact id match.
        _delete.command = ["sh", "-c",
            "cliphist list | awk -F'\\t' -v id=" + _shq(entry.id)
            + " '$1==id{print}' | cliphist delete"]
        _delete.running = true
    }

    function clearAll() { _wipe.running = true }

    // Called by the picker as the user navigates, so the preview pane
    // gets the decoded payload by the time the selection lands.
    function ensureDecoded(entry) {
        if (!entry) return
        if (entry.isImage) {
            if (entry.imagePath) return
            _decodeImage(entry)
        } else {
            if (entry.decodedText !== null) return
            _decodeText(entry)
        }
    }

    // ─── Parsing ───────────────────────────────────────────────────────
    function _parseList(text) {
        const out = []
        const rows = text.split("\n")
        const imgRe = /^\[\[ binary data (.*?) (png|jpg|jpeg|gif|webp|bmp|svg) (\d+)x(\d+) \]\]$/
        for (const line of rows) {
            if (line.length === 0) continue
            const tab = line.indexOf("\t")
            if (tab < 0) continue
            const id = line.slice(0, tab)
            const preview = line.slice(tab + 1)
            const m = preview.match(imgRe)
            out.push({
                id: id,
                preview: preview,
                isImage: !!m,
                ext: m ? m[2] : "",
                width: m ? parseInt(m[3]) : 0,
                height: m ? parseInt(m[4]) : 0,
                sizeText: m ? m[1] : "",
                imagePath: null,
                decodedText: null
            })
            if (out.length >= _maxEntries) break
        }
        return out
    }

    // ─── On-demand decode ──────────────────────────────────────────────
    function _decodeImage(e) {
        if (_decodeImg.running) return   // coalesce rapid nav; next select re-tries
        const path = cacheDir + "/" + e.id + "." + e.ext
        _decodeImg.targetId = e.id
        _decodeImg.targetPath = path
        _decodeImg.command = ["sh", "-c",
            "mkdir -p " + _shq(cacheDir)
            + " && cliphist decode " + _shq(e.id) + " > " + _shq(path)]
        _decodeImg.running = true
    }

    function _decodeText(e) {
        if (_decodeTxt.running) return
        _decodeTxt.targetId = e.id
        _decodeTxt.command = ["cliphist", "decode", e.id]
        _decodeTxt.running = true
    }

    function _updateEntry(id, fields) {
        entries = entries.map(x =>
            x.id === id ? Object.assign({}, x, fields) : x)
    }

    function _shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    // ─── IPC ───────────────────────────────────────────────────────────
    // Target `clipboard`. Co-located with the state it mutates; see
    // Caelestia /tmp/shell services/Wallpapers.qml.
    property IpcHandler _ipc: IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle() }
        function show():   void { root.show() }
        function hide():   void { root.hide() }
    }

    // ─── Processes ─────────────────────────────────────────────────────
    // Declared last so every function above is in scope when signals fire.
    property Process _list: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = root._parseList(text)
        }
    }

    property Process _decodeImg: Process {
        property string targetId: ""
        property string targetPath: ""
        onExited: (code) => {
            if (code === 0)
                root._updateEntry(targetId, { imagePath: targetPath })
        }
    }

    property Process _decodeTxt: Process {
        property string targetId: ""
        stdout: StdioCollector {
            onStreamFinished:
                root._updateEntry(_decodeTxt.targetId, { decodedText: text })
        }
    }

    property Process _copy:   Process {}
    property Process _delete: Process {
        onExited: (code) => { if (code === 0) root.refresh() }
    }
    property Process _wipe: Process {
        command: ["cliphist", "wipe"]
        onExited: (code) => { if (code === 0) root.refresh() }
    }
}
