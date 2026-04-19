import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../theme"

// CalendarPanel — the window-level concerns only:
//   * StyledWindow + scrim
//   * Open/close slide animation (offsetScale)
//   * Ticking clock
//   * Multi-monitor dismiss on focus change
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

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

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

    // ─── Clock + multi-monitor dismiss + scrim ─────────────────────────
    Timer {
        id: clockTick
        property date time: new Date()
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: time = new Date()
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!Ui.calendarOpen) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                Ui.calendarOpen = false
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ui.calendarOpen = false
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.topMargin: Spacing.xs + (-card.height - Spacing.sm) * root.offsetScale
        anchors.horizontalCenter: parent.horizontalCenter
        width: view.calendarWidth
        height: view.implicitHeight + Theme.padLg * 2
        color: Theme.card
        radius: Theme.radiusLg
        border.color: Theme.border
        border.width: 1
        opacity: 1 - root.offsetScale

        // Swallow clicks so the scrim doesn't dismiss us.
        MouseArea { anchors.fill: parent }

        // Paired fade-swap animation on month change. The animation
        // target is the whole CalendarView so the grid + week column +
        // nav move as one.
        SequentialAnimation {
            id: swapAnim
            property int nextMonth: root.viewMonth
            property int nextYear:  root.viewYear

            NumberAnimation {
                target: view; property: "opacity"
                to: 0
                duration: Motion.durationFast
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standardAccel
            }
            ScriptAction {
                script: {
                    root.viewMonth = swapAnim.nextMonth
                    root.viewYear  = swapAnim.nextYear
                }
            }
            NumberAnimation {
                target: view; property: "opacity"
                to: 1
                duration: Motion.durationStd
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standardDecel
            }
        }

        CalendarView {
            id: view
            anchors {
                left: parent.left; right: parent.right
                top: parent.top
                margins: Theme.padLg
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
