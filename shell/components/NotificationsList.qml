import QtQuick
import ".."
import "../theme"

// NotificationsList — history items + empty state. Body-only.
//
// The header (title + count pill + Clear All button) used to live here
// and was shared between NotificationsPopover and ControlCenter. It now
// lives in WingPopover's sticky header API for the popover and inline
// inside ControlCenter for the drawer section — both sites render their
// own chrome so scrolling inside the popover no longer drags the title
// off the top of the card.
//
// ─── Sizing contract ──────────────────────────────────────────────────
// A plain Column positioner — its `implicitHeight` is the sum of the
// laid-out children. Two consumers read this:
//   • NotificationsPopover's Flickable binds contentHeight to this.
//   • ControlCenter's outer Column lays this out vertically alongside
//     MediaCard / BatteryRow / StatCards.
//
// Keep it a Column. Switching to an Item + anchored children collapses to
// height 0 under the ControlCenter layout because Item.height doesn't
// follow implicitHeight automatically.
//
// ─── Empty-state sizing ───────────────────────────────────────────────
// The empty-state Item declares its own fixed 200 px height so the card
// has presence without a collapsed slab. Content-natural sizing in
// WingPopover means we no longer need to fill an arbitrary viewport height
// from outside — the Flickable height follows this implicitHeight.
Column {
    id: root
    spacing: hasMany ? Spacing.sm : Spacing.md

    readonly property bool isEmpty:  Notifs.history.length === 0
    // Section labels + split appear when history is long enough to benefit.
    readonly property bool hasMany:  Notifs.history.length > 10

    // Calendar-day boundary for Today / Earlier split.
    // Computed once per render; updates when history changes.
    readonly property real _todayStart: {
        const d = new Date()
        return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    }

    // ─── Items ────────────────────────────────────────────────────────
    // When hasMany: emit "Today" section label, then today's entries, then
    // "Earlier" label, then earlier entries. When !hasMany: flat list.
    //
    // Implemented as two Repeaters gated on hasMany, plus two section
    // labels. A single Repeater with an inline model-filter function is
    // simpler but prevents the Column from computing implicitHeight from
    // two independently-visible sets. Using two Repeaters keeps the
    // Column layout contract intact.

    // ─── Section: Today ──────────────────────────────────────────────
    Text {
        visible: root.hasMany && !root.isEmpty
        width: parent.width
        topPadding: Spacing.sm
        text: "Today"
        color: Colors.fgDim
        font {
            family: Typography.fontSans
            pixelSize: Typography.fontMicro
            weight: Typography.weightMedium
        }
    }

    Repeater {
        model: root.hasMany ? Notifs.history : []
        delegate: NotificationItem {
            required property var modelData
            entry: modelData
            width: root.width
            // Only show entries from today in this block.
            visible: modelData.time >= root._todayStart
            height: visible ? implicitHeight : 0
        }
    }

    // ─── Section: Earlier ────────────────────────────────────────────
    Text {
        // Only render the "Earlier" label if there are actually earlier entries.
        readonly property bool _hasEarlier: {
            if (!root.hasMany) return false
            for (let i = 0; i < Notifs.history.length; i++) {
                if (Notifs.history[i].time < root._todayStart) return true
            }
            return false
        }
        visible: _hasEarlier
        width: parent.width
        topPadding: Spacing.sm
        text: "Earlier"
        color: Colors.fgDim
        font {
            family: Typography.fontSans
            pixelSize: Typography.fontMicro
            weight: Typography.weightMedium
        }
    }

    Repeater {
        model: root.hasMany ? Notifs.history : []
        delegate: NotificationItem {
            required property var modelData
            entry: modelData
            width: root.width
            // Only show entries older than today.
            visible: modelData.time < root._todayStart
            height: visible ? implicitHeight : 0
        }
    }

    // ─── Flat list (≤10 items) ────────────────────────────────────────
    Repeater {
        model: root.hasMany ? [] : Notifs.history
        delegate: NotificationItem {
            required property var modelData
            entry: modelData
            width: root.width
        }
    }

    // ─── Empty state ──────────────────────────────────────────────────
    // Fixed 200 px — gives the empty card enough presence without relying
    // on a consumer-supplied viewport height. When visible=false (items
    // exist), height collapses to 0 so it doesn't push the Column taller.
    Item {
        width: parent.width
        height: visible ? Sizing.px(200) : 0
        visible: root.isEmpty
        opacity: root.isEmpty ? 1 : 0
        scale:   root.isEmpty ? 1 : 0.92
        Behavior on opacity { Anim { type: "standard" } }
        Behavior on scale   { Anim { type: "spatial" } }

        Column {
            anchors.centerIn: parent
            spacing: Spacing.xs

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""    // bell
                color: Colors.fgDim
                font { family: Typography.fontMono; pixelSize: Typography.fontTitle }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Quiet."
                color: Colors.fgMuted
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontTitle
                    weight: Typography.weightDemiBold
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No notifications"
                color: Colors.fgDim
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
            }
        }
    }
}
