import QtQuick
import Quickshell.Hyprland
import ".."

// ActiveWindow — focused-toplevel title, truncated. Reads directly from
// Hyprland.activeToplevel; updates automatically as focus changes. Shows
// the class as a compact prefix ("Kitty · nvim MEMORY.md") and falls back
// to "Desktop" when nothing is focused.
//
// Style: single-line, muted secondary, right-aligned by parent anchors.
// Kept narrow so it never fights the clock for center space.
Item {
    id: root
    property int maxTextWidth: 220

    readonly property var _tl: Hyprland.activeToplevel
    readonly property string _cls: {
        const c = root._tl?.lastIpcObject?.class ?? ""
        if (!c) return ""
        // Pretty-print: strip org.domain. / drop common suffixes.
        const simple = c.split(".").pop()
        return simple.charAt(0).toUpperCase() + simple.slice(1)
    }
    readonly property string _title: {
        const t = root._tl?.title ?? ""
        if (!t) return "Desktop"
        // Compact form: keep whatever follows the last " — " / " - " dash.
        const parts = t.split(/\s+[\-\u2013\u2014]\s+/)
        return parts.length > 1 ? parts[parts.length - 1].trim() : t
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root._cls.length > 0
            text: root._cls
            color: Theme.fg
            font {
                family: Theme.fontSans
                pixelSize: Theme.fontCaption
                weight: Font.DemiBold
            }
            elide: Text.ElideRight
        }
        Rectangle {
            visible: root._cls.length > 0 && root._title !== "Desktop"
            width: 1; height: 10
            color: Theme.border
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root._title
            color: Theme.fgMuted
            font {
                family: Theme.fontSans
                pixelSize: Theme.fontCaption
                weight: Font.Medium
            }
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.maxTextWidth)
        }
    }
}
