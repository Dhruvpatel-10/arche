pragma Singleton
import QtQuick

// Osd — generic pill state machine. Knows nothing about volume, brightness,
// or any specific domain; just holds the currently-shown payload and runs
// the auto-hide timer.
//
// Providers (VolumeProvider, BrightnessProvider, …) translate their domain
// into a payload and call `show()`. The OsdOverlay component reads
// `payload` and renders.
//
// Payload schema (all fields optional unless noted):
//
//   icon     string   required — nerd-font glyph for the left disc
//   percent  int      0–100. If present, a progress bar is shown.
//   label    string   replaces the "nn%" readout on the right
//                     (e.g. "Muted", "Caps Lock On")
//   variant  string   "normal" | "muted" | "warn" — styling cue
//                     consumed by OsdOverlay
//
// To add a new OSD type: write a provider in osd/, register it in
// osd/qmldir, add an IpcHandler method in shell.qml, chain the hypr
// keybind. No change to Osd.qml or OsdOverlay.qml needed unless the new
// type wants a field the schema doesn't cover yet.
QtObject {
    id: root

    property bool active:  false
    property var  payload: ({ icon: "", percent: -1, label: "", variant: "normal" })

    // Auto-hide delay. Resets on each `show()` so holding a key keeps the
    // pill on screen without flicker.
    readonly property int timeoutMs: 1500

    function show(p) {
        payload = Object.assign(
            { icon: "", percent: -1, label: "", variant: "normal" },
            p || {}
        )
        active = true
        _hide.restart()
    }

    function hide() { active = false; _hide.stop() }

    property Timer _hide: Timer {
        interval: root.timeoutMs
        repeat: false
        onTriggered: root.active = false
    }
}
