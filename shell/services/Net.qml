pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Net — wifi state + radio control. `ssid`/`connected` describe the active
// connection; `radioOn` reflects the radio switch (independent of whether
// a network is joined). `toggle()` flips the radio via `nmcli radio wifi`.
// `scanList` is populated lazily by `scan()` / `rescan()` — callers that
// need nearby networks (NetworkPopover) trigger it; the bar pill does not.
// One instance per shell; bar pill and control-center tile both read this.
QtObject {
    id: root
    property string ssid: ""
    property bool connected: false
    property bool radioOn: true

    // Last scan result. Entries: { ssid, signal, security, inUse }.
    // Populated by the scan process; empty until scan()/rescan() runs.
    property var scanList: []
    property bool scanning: false
    property string connectError: ""   // last nmcli connect error (if any)

    property Process queryConn: Process {
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID,TYPE dev wifi | awk -F: '$1==\"yes\" && $3==\"\"{print $2; exit} $1==\"yes\"{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ssid = text.trim()
                root.connected = root.ssid.length > 0
            }
        }
    }

    property Process queryRadio: Process {
        command: ["sh", "-c", "nmcli -t radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.radioOn = text.trim() === "enabled"
        }
    }

    property Process toggler: Process {}

    // Scan nearby wifi. nmcli's -t output is a tab-separated tuple per
    // network: IN-USE:SSID:SIGNAL:SECURITY. We dedupe by SSID (same AP
    // can show multiple times for different BSSIDs) and keep the strongest.
    property Process scanner: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                 "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                for (const line of text.split("\n")) {
                    const parts = line.split(":")
                    if (parts.length < 4) continue
                    const ssid = parts[1]
                    if (!ssid) continue
                    const sig = parseInt(parts[2]) || 0
                    const existing = seen[ssid]
                    if (!existing || sig > existing.signal) {
                        seen[ssid] = {
                            ssid: ssid,
                            signal: sig,
                            security: parts[3],
                            inUse: parts[0] === "*",
                        }
                    }
                }
                const list = Object.values(seen).sort((a, b) => b.signal - a.signal)
                root.scanList = list
                root.scanning = false
            }
        }
    }

    property Process connecter: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectError = ""
                root.refreshSoon.restart()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.connectError = t
            }
        }
    }

    function toggle() {
        const next = root.radioOn ? "off" : "on"
        root.radioOn = !root.radioOn
        toggler.command = ["nmcli", "radio", "wifi", next]
        toggler.running = true
        refreshSoon.restart()
    }

    // Trigger a live rescan + refresh the scanList. Safe to call from
    // multiple popovers; concurrent calls are dropped by the running-check
    // so the in-flight nmcli isn't stomped. `scanning` stays true until
    // the running scanner finishes.
    function scan() {
        if (!root.radioOn) return
        if (root.scanner.running) return
        root.scanning = true
        root.scanner.running = true
    }

    function rescan() {
        // Force an immediate re-probe; nmcli will return quickly even if
        // the driver caches. For a deeper rescan users can use impala.
        root.scan()
    }

    // Connect to a saved (or open) network. For secured networks with no
    // stored creds nmcli returns a "802-11-wireless-security" error; the
    // popover catches this via `connectError` and surfaces an "Open
    // impala" hint.
    //
    // Re-entry guard: `connecter` is shared between connect/disconnect.
    // Writing `command` + `running = true` while the Process is already
    // running silently no-ops — drop the call instead of swallowing it.
    function connectTo(ssid) {
        if (root.connecter.running) return
        root.connectError = ""
        root.connecter.command = ["nmcli", "dev", "wifi", "connect", ssid]
        root.connecter.running = true
    }

    function disconnect() {
        if (root.connecter.running) return
        root.connecter.command = ["nmcli", "connection", "down",
                                  "id", root.ssid]
        root.connecter.running = true
    }

    // Re-entry guards: nmcli can stall under load (agent hangups, driver
    // blips). If a previous poll is still in flight, drop this tick rather
    // than stomp the command on the running Process.
    function _pollOnce() {
        if (!root.queryRadio.running) root.queryRadio.running = true
        if (!root.queryConn.running)  root.queryConn.running  = true
    }

    // After a toggle, nmcli takes a moment to settle. Re-query shortly so
    // the bound UI reflects the real final state (and corrects our optimistic
    // flip above if the command failed).
    property Timer refreshSoon: Timer {
        interval: 600
        repeat: false
        onTriggered: {
            root._pollOnce()
            if (root.radioOn) root.scan()
        }
    }

    property Timer timer: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._pollOnce()
    }
}
