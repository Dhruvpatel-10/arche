import Quickshell
import Quickshell.Io
import "."
import "./osd"

// Shortcuts — cross-cutting IPC dispatch that doesn't belong inside any
// single service. Service-local handlers live inside the service itself
// (Notifs owns `notifs`, Clipboard owns `clipboard`); this file only
// hosts triggers that fan out across multiple producers, or that touch
// no service state at all.
//
// Pattern from /tmp/shell (Caelestia): co-locate IPC with the thing it
// controls; reserve the global `Shortcuts` for what genuinely has no
// owner. Makes `grep -r IpcHandler` land on the right file every time.
Scope {
    // On-screen display — chained onto XF86Audio*/XF86MonBrightness*
    // bindings in stow/hypr/media.conf. Dispatches into per-kind
    // provider singletons (VolumeProvider, BrightnessProvider). Owned
    // here because the OSD is a rendering surface, not a service.
    IpcHandler {
        target: "osd"
        function volume():     void { OsdVolume.trigger() }
        function brightness(): void { OsdBrightness.trigger() }
    }
}
