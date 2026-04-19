import QtQuick
import ".."
import "./powermenu"

// PowerMenuDialog — session/power actions (lock, sleep, logout, reboot,
// shutdown). Consumes PickerDialog; all scrim/card/search/list wiring
// is inherited. Replaces the legacy rofi-backed arche-powermenu script.
PickerDialog {
    id: picker

    pickerName: "powermenu"
    prompt:     "Power"

    open:       PowerMenu.open
    items:      PowerMenu.actions
    itemIdRole: "id"

    maxWidth:  480
    maxHeight: 520

    filter: (it, q) => it.label.toLowerCase().includes(q)

    hints: [
        { k: "↵",   v: "Run"   },
        { k: "Esc", v: "Close" }
    ]

    onDismissed:           PowerMenu.hide()
    onAccepted: (i, item)  => PowerMenu.run(item)

    delegate: PowerMenuItem {
        required property var modelData
        required property int index
        width:    ListView.view.width
        action:   modelData
        selected: ListView.isCurrentItem
        onActivated: picker.accept(index)
    }
}
