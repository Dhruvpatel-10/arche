import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../theme"

// CalendarPanel — the window-level concerns only:
//   * StyledWindow + scrim
//   * Open/close slide animation (offsetScale)
//   * Ticking clock
//   * Multi-monitor: bind `screen` to focused monitor (drawer follows focus)
//   * Keyboard focus + Escape dismissal
//   * viewMonth / viewYear / selectedDate state + nav helpers
//   * Fade swap animation on month change
//
// Everything visual is owned by CalendarView.qml.
StyledWindow {
    id: root
    name: "calendar"

    // ─── Slide + fade driver (shared pattern with ControlCenter) ───────
    readonly property bool shouldBeActive: Ui.calendarOpen
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: shouldBeActive || offsetScale < 1

    Behavior on offsetScale {
        Anim { type: "spatial" }
    }

    // Multi-monitor: render on the currently-focused monitor. Same
    // pattern as PickerDialog/ControlCenter — resolve the Hyprland
    // monitor to the matching ShellScreen by name.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (list[i].name === fm.name) return list[i]
        return null
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    // OnDemand keyboard focus: the FocusScope below grabs focus and
    // handles Escape dismissal.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // ─── View state ────────────────────────────────────────────────────
    property int viewMonth: new Date().getMonth()
    property int viewYear:  new Date().getFullYear()
    property var selectedDate: new Date()

    // Reset on every open — land on today, select today.
    onVisibleChanged: {
        if (!visible) return
        const d = new Date()
        viewMonth = d.getMonth()
        viewYear  = d.getFullYear()
        selectedDate = d
    }

    // ─── Clock + scrim + focus ────────────────────────────────────────
    Timer {
        id: clockTick
        property date time: new Date()
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: time = new Date()
    }

    // Note: no focused-monitor-changed dismiss handler. The `screen`
    // binding above already follows Hyprland.focusedMonitor — the panel
    // simply hops to the new monitor (matching PickerDialog's UX).

    // Escape dismissal. FocusScope pulls the layer's OnDemand keyboard
    // focus so Esc fires here. Transparent; doesn't consume mouse events.
    FocusScope {
        anchors.fill: parent
        focus: root.shouldBeActive
        Keys.onEscapePressed: Ui.calendarOpen = false
    }

    // Scrim: left-click outside the card dismisses. Right-clicks fall
    // through — the scrim shouldn't swallow context menus on whatever
    // surface lives below us.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: Ui.calendarOpen = false
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: Spacing.xs + (-card.height - Spacing.sm) * root.offsetScale
        anchors.horizontalCenter: parent.horizontalCenter
        width: view.calendarWidth
        height: view.implicitHeight + Spacing.lg * 2
        color: Colors.card
        radius: Shape.radiusLg
        border.color: Colors.border
        border.width: Shape.borderThin
        opacity: 1 - root.offsetScale

        // Swallow clicks so the scrim doesn't dismiss us.
        MouseArea { anchors.fill: parent }

        // Paired fade-swap animation on month change. Leaving half uses
        // the `accel` preset (standardAccel — drives *into* the exit),
        // arriving half uses `decel` (standardDecel — eases *out* of the
        // entrance). The animation target is the whole CalendarView so
        // the grid + week column + nav move as one.
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

        CalendarView {
            id: view
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                margins: Spacing.lg
            }
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
}
