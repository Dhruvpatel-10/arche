import QtQuick
import QtQuick.Layouts
import ".."
import "../theme"

// StyledDialog — thin back-compat shim over `ArcheDialog { mode: "modal" }`.
//
// Prior to the ArcheDialog base, this file carried its own scrim + card +
// offsetScale driver + focus / monitor dismissal wiring. That plumbing
// now lives in `ArcheDialog.qml` — every surface (popover or modal) extends
// the same primitive so pitfall coverage is declared in exactly one
// place (see ArcheDialog.qml's header for the full pitfall checklist).
//
// StyledDialog preserves the old role/maxWidth/maxHeight API so existing
// consumers (`PowerMenuConfirm`) continue to work without a rewrite.
// New modal work should target `ArcheDialog { mode: "modal" }` directly.
//
// Role mapping:
//   rolePicker  (0) — Picker dialogs (PickerDialog has its own plumbing;
//                     this role is reserved for future non-Picker uses).
//   roleConfirm (1) — Confirmation dialogs (PowerMenuConfirm).
//
// Both roles render as centered modals with Exclusive keyboard focus.
// `dangerDefault` is a consumer-level hint the caller reads back — this
// wrapper passes it through as a queryable property; nothing in the base
// reacts to it.
//
// Dismissal reasons re-emitted from ArcheDialog:
//   outside, esc, monitor-left, cursor-left, commit, cancel, action
ArcheDialog {
    id: root

    // ─── Role constants (legacy) ──────────────────────────────────────
    readonly property int rolePicker:  0
    readonly property int roleConfirm: 1

    // ─── Back-compat API ───────────────────────────────────────────────
    property int  role:      0
    property int  maxWidth:  Sizing.px(480)
    property int  maxHeight: Sizing.px(560)
    property bool dangerDefault: false

    // Forward into ArcheDialog's layout props.
    mode:          "modal"
    cardMaxWidth:  maxWidth
    cardMaxHeight: maxHeight
}
