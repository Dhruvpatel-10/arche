import QtQuick
import ".."
import "./launcher"

// LauncherDialog — application launcher on the PickerDialog base.
// Replaces `rofi -show drun`. Filtering + ranking runs upstream in the
// Launcher singleton (async fzf); the dialog binds `items` directly
// to the ranked result so `filter` stays null. Async selection drift
// is handled by the base's new id-anchored preservation — no consumer
// workaround needed.
PickerDialog {
    id: picker

    pickerName:  "launcher"
    prompt:      "Apps"
    placeholder: "Search applications"

    open:       Launcher.open
    items:      Launcher.filtered
    itemIdRole: "id"
    filter:     null
    loading:    Launcher.loading

    // Async backend: every items refresh is the direct response to a
    // keystroke, so preserving the prior selection is wrong — freshly
    // ranked results should start at the top.
    preserveSelectionOnItemsChange: false

    maxWidth:  560
    maxHeight: 560

    hints: [
        { k: "↵",   v: "Launch" },
        { k: "Esc", v: "Close"  }
    ]

    onDismissed:          Launcher.hide()
    onAccepted: (i, item) => Launcher.launch(item)

    // Forward keystrokes to the async pipeline. The base's own
    // `onQueryChanged` still runs alongside (resets selection,
    // snapshots the previous id) — Connections chains cleanly with
    // inline handlers in the base.
    Connections {
        target: picker
        function onQueryChanged() { Launcher.setQuery(picker.query) }
    }

    delegate: LauncherItem {
        required property var modelData
        required property int index
        width:    ListView.view.width
        app:      modelData
        selected: ListView.isCurrentItem
        onActivated: picker.accept(index)
    }
}
