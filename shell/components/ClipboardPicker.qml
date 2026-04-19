import QtQuick
import ".."
import "./clipboard"

// ClipboardPicker — cliphist browser built on PickerDialog. The base
// owns scrim/card/search/list plumbing; this file wires it to the
// Clipboard singleton and supplies the row delegate + preview pane.
PickerDialog {
    id: picker

    pickerName:  "clipboard"
    prompt:      "Clipboard"
    placeholder: "Search"

    open:       Clipboard.open
    items:      Clipboard.entries
    itemIdRole: "id"

    maxWidth:      960
    maxHeight:     560
    leftPaneWidth: 360

    filter: (it, q) => it.preview.toLowerCase().includes(q)

    hints: [
        { k: "↵",   v: "Paste"  },
        { k: "Del", v: "Remove" },
        { k: "Esc", v: "Close"  }
    ]

    onDismissed:                 Clipboard.hide()
    onAccepted:  (i, item)  =>   Clipboard.pick(item)
    onRemoved:   (i, item)  =>   Clipboard.remove(item)
    onSelectionChanged: (i, item) => Clipboard.ensureDecoded(item)

    delegate: EntryItem {
        required property var modelData
        required property int index
        width:    ListView.view.width
        entry:    modelData
        selected: ListView.isCurrentItem
        onActivated: picker.accept(index)
        onRemoved:   picker.remove(index)
    }

    rightPane: Preview {
        entry: picker.selected
    }
}
