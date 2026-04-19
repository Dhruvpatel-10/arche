// Pure JS helpers for CalendarView.qml. No QML imports — date math
// only. Written as a stateless library so QML callers pass locale-
// dependent parameters in (firstDayOfWeek, weekday short names) rather
// than this file reaching up into Qt.locale().
//
// Pattern borrowed from end-4/dots-hyprland calendar_layout.js —
// moving the 6×7 grid math out of QML keeps the view file a pure
// renderer.

.pragma library

// ─── Primitives ────────────────────────────────────────────────────────

function addDays(d, n) {
    const x = new Date(d.valueOf())
    x.setDate(x.getDate() + n)
    return x
}

function sameDate(a, b) {
    return !!a && !!b
        && a.getFullYear() === b.getFullYear()
        && a.getMonth()    === b.getMonth()
        && a.getDate()     === b.getDate()
}

// ISO 8601 week number via the Thursday-rule. Works for any day in the
// target week (Mon..Sun all yield the same week number). Handles year
// boundaries correctly — Jan 1–3 can belong to previous year's week 52
// or 53 per ISO 8601.
function isoWeek(date) {
    const t = new Date(date.valueOf())
    t.setHours(0, 0, 0, 0)
    t.setDate(t.getDate() + 3 - ((t.getDay() + 6) % 7))
    const yearStart = new Date(t.getFullYear(), 0, 1)
    return Math.ceil((((t - yearStart) / 86400000) + 1) / 7)
}

// ─── Labels ────────────────────────────────────────────────────────────

function relativeLabel(d) {
    if (!d) return ""
    const t0 = new Date(); t0.setHours(0, 0, 0, 0)
    const td = new Date(d.valueOf()); td.setHours(0, 0, 0, 0)
    const diff = Math.round((td.getTime() - t0.getTime()) / 86400000)
    if (diff === 0)  return "Today"
    if (diff === 1)  return "Tomorrow"
    if (diff === -1) return "Yesterday"
    if (diff >  0 && diff <  14) return "in " + diff + " days"
    if (diff <  0 && diff > -14) return Math.abs(diff) + " days ago"
    const w = Math.round(diff / 7)
    return w > 0 ? "in " + w + " weeks" : Math.abs(w) + " weeks ago"
}

// ─── Grid builder ──────────────────────────────────────────────────────

// Returns a flat 49-item array: [ header(7) ] + [ row(7) × 6 ].
//
// Each entry has a `role`:
//   "headerDay" — weekday label ({ label })
//   "day"       — day cell ({ day, date, inMonth })
//
// Parameters:
//   year, month         — viewed month (month is 0-indexed, JS-style)
//   firstDayOfWeek      — 0=Sunday…6=Saturday (from Qt.locale().firstDayOfWeek)
//   weekdayShortNames   — array[7] of short names, already rotated to
//                         start at firstDayOfWeek
function buildCells(year, month, firstDayOfWeek, weekdayShortNames) {
    const cells = []

    // Row 0: header
    for (let c = 0; c < 7; c++) {
        cells.push({ role: "headerDay", label: weekdayShortNames[c] })
    }

    // Top-left of the 6×7 day grid.
    const firstOfMonth = new Date(year, month, 1)
    const offset = (firstOfMonth.getDay() - firstDayOfWeek + 7) % 7
    const firstCell = new Date(year, month, 1 - offset)

    for (let r = 0; r < 6; r++) {
        const rowStart = addDays(firstCell, r * 7)
        for (let c = 0; c < 7; c++) {
            const d = addDays(rowStart, c)
            cells.push({
                role: "day",
                date: d,
                day: d.getDate(),
                inMonth: d.getMonth() === month && d.getFullYear() === year
            })
        }
    }

    return cells
}
