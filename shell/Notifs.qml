pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

NotificationServer {
    id: root

    // IPC target `notifs`. Hyprland binds dispatch via
    //   qs ipc call notifs dismissOne
    // Co-located with the notification state it operates on, per the
    // Caelestia pattern — see /tmp/shell services/Notifs.qml.
    property IpcHandler _ipc: IpcHandler {
        target: "notifs"
        function dismissOne(): void { root.dismissOne() }
        function clearAll():   void { root.clearHistory() }
    }


    keepOnReload: true
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    property var toasts: []
    readonly property int toastTimeoutMs: 5000

    // Capped in-memory history. Survives dismiss/expire so the user can scan
    // back through what happened. Cleared via the panel's Clear All button.
    property var history: []
    readonly property int historyMax: 50

    onNotification: n => {
        n.tracked = true
        toasts = [...toasts, n]
        const t = toastTimerComponent.createObject(root, { target: n })
        t.running = true

        const entry = {
            id: n.id,
            summary: n.summary,
            body: n.body,
            appName: n.appName,
            appIcon: n.appIcon,
            time: Date.now(),
            dismissed: false
        }
        history = [entry, ...history].slice(0, historyMax)

        n.closed.connect(reason => {
            // Drop from live toasts so the popup disappears instantly on
            // dismiss (otherwise it only goes away when its own timer fires).
            toasts = toasts.filter(t => t !== n)
            history = history.map(e =>
                (e.id === entry.id && e.time === entry.time)
                    ? Object.assign({}, e, { dismissed: true })
                    : e)
        })
    }

    function dismissAll() {
        const list = trackedNotifications.values.slice()
        for (const n of list) n.dismiss()
        toasts = []
    }

    function clearHistory() {
        dismissAll()
        history = []
    }

    function removeFromHistory(entry) {
        history = history.filter(e => !(e.id === entry.id && e.time === entry.time))
    }

    // Dismiss the oldest live toast. Repeated calls walk through the stack.
    function dismissOne() {
        if (toasts.length === 0) return
        toasts[0].dismiss()
    }

    // Returns true if a default action was invoked for the given notification.
    // Used by both live toasts (Toast.qml) and history items (NotificationItem.qml).
    function invokeDefault(appName, appIcon, body) {
        if (appName === "Screenshot") {
            if (typeof appIcon === "string" && appIcon.startsWith("/")) {
                // Fast path: absolute path known — launch satty directly.
                Quickshell.execDetached(["satty",
                    "--filename", appIcon,
                    "--output-filename", appIcon,
                    "--copy-command", "wl-copy -t image/png"
                ])
                return true
            }
            if (body) {
                // Fallback: reconstruct via shell so $HOME expands.
                const quoted = JSON.stringify("$HOME/Pictures/Screenshots/" + body)
                Quickshell.execDetached(["sh", "-c",
                    'f=' + quoted + '; '
                    + '[ -f "$f" ] && '
                    + 'exec satty --filename "$f" '
                    + '--output-filename "$f" '
                    + '--copy-command "wl-copy -t image/png"'
                ])
                return true
            }
        }
        return false
    }

    function _expireToast(n) {
        toasts = toasts.filter(t => t !== n)
    }

    property Component toastTimerComponent: Component {
        Timer {
            property var target: null
            interval: root.toastTimeoutMs
            repeat: false
            onTriggered: {
                root._expireToast(target)
                destroy()
            }
        }
    }
}
