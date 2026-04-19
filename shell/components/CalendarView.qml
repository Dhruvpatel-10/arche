import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../theme"
import "./calendar_layout.js" as CalLayout

// CalendarView — pure view for the calendar card interior.
//
// Layout philosophy:
//   ONE Grid with 8 columns drives both the weekday header AND the six
//   day-number rows. Using a single Grid locks the column pitch — every
//   header cell, week-number cell, and day cell shares the same column
//   so nothing skews at sub-pixel scale. This is why `MonthGrid +
//   WeekNumberColumn + DayOfWeekRow` misaligned: three Items each
//   owned their own column math.
//
// ISO week numbers:
//   Qt's native WeekNumberColumn uses the first cell of the row (Sunday
//   on en_US) to look up the ISO week, but ISO weeks start on Monday.
//   For a Sunday-first display the row "Sun Apr 19 … Sat Apr 25" should
//   show week 17 (ISO week of Mon Apr 20), not 16 (ISO week of Sun Apr
//   19 which is the LAST day of week 16). We compute manually using the
//   +3-day Thursday-rule, which is locale-independent.
Item {
    id: root

    // ─── Inputs ────────────────────────────────────────────────────────
    property int  viewMonth: 0
    property int  viewYear:  1970
    property var  selectedDate: null
    property date today: new Date()

    // ─── Outputs ───────────────────────────────────────────────────────
    signal dayClicked(var d)              // JS Date
    signal navRequested(int dMonth, int dYear)
    signal todayRequested()
    signal powermenuRequested()

    // ─── Layout metrics (single source of truth) ───────────────────────
    readonly property int cellSize:  Sizing.px(38)
    readonly property int cellGap:   Spacing.xs       // 4 px

    // Card width derived from the grid so the panel re-sizes with the
    // theme scale. Includes inner body padding.
    readonly property int calendarWidth:
        7 * cellSize + 6 * cellGap + 2 * Spacing.lg

    // ─── Derived state ─────────────────────────────────────────────────
    // Weekday short names rotated so element [0] matches the locale's
    // first day of week. Computed once per locale change.
    readonly property var _weekdayShortNames: {
        const locale = Qt.locale()
        const first  = locale.firstDayOfWeek
        const names  = []
        for (let c = 0; c < 7; c++)
            names.push(locale.dayName((first + c) % 7, Locale.ShortFormat))
        return names
    }

    // All grid math lives in calendar_layout.js — see there.
    readonly property var _cells: CalLayout.buildCells(
        root.viewYear,
        root.viewMonth,
        Qt.locale().firstDayOfWeek,
        root._weekdayShortNames
    )

    // ─── Render ────────────────────────────────────────────────────────
    implicitWidth:  body.implicitWidth
    implicitHeight: body.implicitHeight

    Column {
        id: body
        width: parent.width
        spacing: 12

        // Clock + date block
        Column {
            width: parent.width
            spacing: 2
            Text {
                text: Qt.formatTime(root.today, "HH:mm")
                color: Theme.fg
                font {
                    family:    Theme.fontSans
                    pixelSize: Theme.fontDisplay
                    weight:    Font.DemiBold
                    features:  { "tnum": 1 }
                }
            }
            Text {
                text: Qt.formatDate(root.today, "dddd, MMMM d, yyyy")
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontBody }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.5 }

        // Nav row
        RowLayout {
            width: parent.width
            spacing: 4

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                color: Theme.fg
                font {
                    family:    Theme.fontSans
                    pixelSize: Theme.fontBody
                    weight:    Font.DemiBold
                }
            }
            IconButton {
                width: 24; height: 24; radius: 12
                icon: "\uf100"; iconSize: 9
                onClicked: root.navRequested(0, -1)
            }
            IconButton {
                width: 24; height: 24; radius: 12
                icon: "\uf053"; iconSize: 9
                onClicked: root.navRequested(-1, 0)
            }
            IconButton {
                width: 24; height: 24; radius: 12
                icon: "\uf783"; iconSize: 9
                onClicked: root.todayRequested()
            }
            IconButton {
                width: 24; height: 24; radius: 12
                icon: "\uf054"; iconSize: 9
                onClicked: root.navRequested(1, 0)
            }
            IconButton {
                width: 24; height: 24; radius: 12
                icon: "\uf101"; iconSize: 9
                onClicked: root.navRequested(0, 1)
            }
        }

        // The one grid — 1 header row + 6 day rows, 7 columns.
        Item {
            id: gridWrap
            width: parent.width
            implicitHeight: grid.implicitHeight
            clip: true

            Grid {
                id: grid
                columns: 7
                columnSpacing: root.cellGap
                rowSpacing:    root.cellGap

                Repeater {
                    model: root._cells
                    delegate: Item {
                        id: slot
                        required property var modelData

                        readonly property string role: modelData?.role ?? ""

                        width:  root.cellSize
                        height: role === "headerDay"
                                    ? (Theme.fontCaption + 8)
                                    : root.cellSize

                        // Header weekday label
                        Text {
                            anchors.centerIn: parent
                            visible: slot.role === "headerDay"
                            text: slot.modelData?.label ?? ""
                            color: Theme.fgMuted
                            font {
                                family:    Theme.fontSans
                                pixelSize: Theme.fontCaption
                                weight:    Font.DemiBold
                            }
                        }

                        // Day cell
                        CalendarDay {
                            anchors.fill: parent
                            visible: slot.role === "day"
                            dayNumber:  slot.modelData?.day ?? 0
                            inMonth:    slot.modelData?.inMonth ?? false
                            isToday:    slot.role === "day"
                                        && (slot.modelData?.inMonth ?? false)
                                        && CalLayout.sameDate(slot.modelData.date, root.today)
                            isSelected: slot.role === "day"
                                        && (slot.modelData?.inMonth ?? false)
                                        && root.selectedDate
                                        && !isToday
                                        && CalLayout.sameDate(slot.modelData.date, root.selectedDate)
                            onClicked: root.dayClicked(slot.modelData.date)
                        }
                    }
                }
            }
        }

        // Footer: selected-date echo + relative label
        Rectangle {
            visible: root.selectedDate !== null
            width: parent.width; height: 1
            color: Theme.border; opacity: 0.5
        }

        RowLayout {
            visible: root.selectedDate !== null
            width: parent.width
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.selectedDate
                      ? Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                      : ""
                color: Theme.fg
                font {
                    family:    Theme.fontSans
                    pixelSize: Theme.fontCaption
                    weight:    Font.DemiBold
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: CalLayout.relativeLabel(root.selectedDate)
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
            }
        }
    }

}
