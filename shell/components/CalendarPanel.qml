import QtQuick
import ".."
import "../theme"

// CalendarPanel — top-centered calendar popover.
//
// Built on ArcheDialog { mode: "popover"; anchorEdge: "center" }. Every
// window-level concern — scrim, Esc dismissal, click-outside, focused-
// monitor teleport, slide/fade animation, namespace — is inherited from
// the base. See ArcheDialog.qml's header for the full pitfall checklist.
//
// CalendarPanel owns only the calendar-specific state:
//   * viewMonth / viewYear / selectedDate (current render target)
//   * clockTick (Timer driving the time readout)
//   * swapAnim (paired fade on month / year change)
//
// The calendar's long-standing feel — the 500 ms spatial slide with a
// gentle overshoot on landing — is now the popover-mode default on
// ArcheDialog; every bar-wing popover inherits it too. This file is the
// consumer; the base is where the motion lives.
ArcheDialog {
    id: root
    name: "calendar"

    mode:       "popover"
    anchorEdge: "center"

    // Open follows the Ui flag; every dismissal path funnels into one
    // action — clear the flag. ArcheDialog handles the rest (Esc,
    // outside-click, monitor-change).
    open: Ui.calendarOpen
    onDismissed: Ui.calendarOpen = false

    // Card sized to the calendar grid. `view.calendarWidth` already
    // includes the 2×Spacing.lg internal gutter; ArcheDialog's
    // `contentPadding` default is the same Spacing.lg so the grid lands
    // flush inside the card without double-padding.
    cardWidth: view.calendarWidth
    // Generous ceiling so the card never exceeds the screen. The
    // ColumnLayout inside ArcheDialog already shrinks to
    // `childrenRect.height` in popover mode — this just stops a
    // hypothetical future content overflow.
    cardMaxHeight: Math.max(Sizing.px(320),
                            Math.round((root.height - root.anchorTopMargin)
                                       * 0.85))

    // ─── View state ────────────────────────────────────────────────────
    property int viewMonth: new Date().getMonth()
    property int viewYear:  new Date().getFullYear()
    property var selectedDate: new Date()

    // Reset to today on every open. `open` is the user-intent flag, so
    // this fires once per open — matching the old `onVisibleChanged`
    // reset semantics without racing the animation tail (visible stays
    // true during close-out).
    onOpenChanged: {
        if (!open) return
        const d = new Date()
        viewMonth = d.getMonth()
        viewYear  = d.getFullYear()
        selectedDate = d
    }

    // ─── Ticking clock ────────────────────────────────────────────────
    // Drives the time display inside CalendarView. Only runs while the
    // card is on-screen (visible includes the close-out animation).
    Timer {
        id: clockTick
        property date time: new Date()
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: time = new Date()
    }

    // ─── Paired fade-swap on month change ─────────────────────────────
    // Leaving half uses the `accel` preset (standardAccel — drives *into*
    // the exit), arriving half uses `decel` (standardDecel — eases *out
    // of* the entrance). The animation target is the whole CalendarView
    // so the grid + week column + nav move as one.
    SequentialAnimation {
        id: swapAnim
        property int nextMonth: root.viewMonth
        property int nextYear:  root.viewYear

        Anim { target: view; property: "opacity"; to: 0; type: "accel" }
        ScriptAction {
            script: {
                root.viewMonth = swapAnim.nextMonth
                root.viewYear  = swapAnim.nextYear
            }
        }
        Anim { target: view; property: "opacity"; to: 1; type: "decel" }
    }

    // ─── Content ──────────────────────────────────────────────────────
    // Children of ArcheDialog go into the card's content area (an Item
    // under the optional header / footer slots). CalendarView anchors
    // left/right to span the content area and sets `height:
    // implicitHeight` so the card can shrink to fit in popover mode
    // (cardInterior's Layout.preferredHeight reads childrenRect.height).
    CalendarView {
        id: view
        anchors.left:  parent.left
        anchors.right: parent.right
        height:        implicitHeight

        viewMonth:    root.viewMonth
        viewYear:     root.viewYear
        selectedDate: root.selectedDate
        today:        clockTick.time

        onDayClicked: d => root.selectedDate = d
        onNavRequested: (dm, dy) => {
            let m = root.viewMonth + dm
            let y = root.viewYear  + dy
            while (m < 0)  { m += 12; y -= 1 }
            while (m > 11) { m -= 12; y += 1 }
            swapAnim.nextMonth = m
            swapAnim.nextYear  = y
            swapAnim.restart()
        }
        onTodayRequested: {
            const d = new Date()
            swapAnim.nextMonth = d.getMonth()
            swapAnim.nextYear  = d.getFullYear()
            swapAnim.restart()
            root.selectedDate = d
        }
    }
}
