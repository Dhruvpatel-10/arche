pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire
import "."

// VolumeProvider — translates Pipewire sink state into an OSD payload.
// Triggered explicitly via `qs ipc call osd volume` (chained onto the
// XF86Audio* key bindings in stow/hypr/media.conf) — we do NOT pop the
// OSD on every Pipewire tick, because that would flash on unrelated
// volume changes (new-app default, streaming app auto-set, etc).
QtObject {
    function trigger() {
        const sink = Pipewire.defaultAudioSink?.audio
        const p    = Math.round(((sink?.volume ?? 0) * 100))
        const m    = sink?.muted ?? false
        Osd.show({
            icon:    _icon(p, m),
            percent: m ? 0 : p,
            label:   m ? "Muted" : "",
            variant: m ? "muted" : "normal"
        })
    }

    function _icon(p, muted) {
        if (muted)   return "\uf6a9"   // speaker-mute (nf-fa-volume_mute)
        if (p === 0) return "\uf026"   // speaker-off
        if (p < 50)  return "\uf027"   // speaker-low
        return                "\uf028" // speaker-high
    }
}
