import QtQuick
import "../../theme"

// PickerItemBase — shared row chrome for picker delegates.
//
// Every delegate wants the same things: fixed row height, 8px radius,
// accent-tinted selection, pointer cursor, click-to-activate. Before
// this file those lines were triplicated across EntryItem /
// LauncherItem / PowerMenuItem; now they live here and each delegate
// supplies only its content.
//
// ─── No hover-to-select (and why) ──────────────────────────────────────
// The canonical keyboard-first launchers — VSCode Quick Input,
// Chromium omnibox, PowerToys CmdPal, Spotlight, Raycast, Alfred,
// GNOME Activities — all treat hover as a purely visual affordance
// (cursor shape, optional CSS tint), completely decoupled from the
// keyboard-selection cursor. Only rofi implements hover-moves-
// selection, and even there users complain about it on sloppy-focus
// setups.
//
// The case for dropping hover-select in Qt/QML is stronger: Qt's
// scene graph delivers `QHoverEvent::Enter` to any newly-instantiated
// MouseArea that finds itself under a stationary cursor when the item
// hierarchy reshuffles (verified in Qt docs and confirmed as the root
// cause of our "typed Viv, cursor on NVIDIA" bug). `onEntered` fires
// without pointer motion. No timer or arm-gate closes that hole
// without permanently disarming hover — at which point hover-select
// wasn't doing anything anyway. So we drop it.
//
// The pointer-cursor change (cursorShape: PointingHandCursor) is the
// hover affordance. Clicks still activate atomically. Keyboard
// exclusively drives `selectedIndex`.
Rectangle {
    id: root

    // ─── Contract ──────────────────────────────────────────────────────
    required property bool selected

    property int  rowHeight:         Sizing.px(48)
    property bool rightClickRemoves: false

    signal activated()
    signal removed()

    // ─── Chrome ────────────────────────────────────────────────────────
    implicitHeight: rowHeight
    radius:         Sizing.px(8)
    // Selected rows get the accent at ~11% opacity — a warm wash that
    // reads as "this row is focused" without fighting the list's text.
    color: root.selected
        ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.11)
        : "transparent"

    // ─── Input ─────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        acceptedButtons: root.rightClickRemoves
            ? (Qt.LeftButton | Qt.RightButton)
            : Qt.LeftButton

        onClicked: (m) => m.button === Qt.RightButton
            ? root.removed()
            : root.activated()
    }
}
