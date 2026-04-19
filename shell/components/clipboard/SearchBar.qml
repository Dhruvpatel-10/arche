import QtQuick
import "../.."

// Search bar. Left label mirrors the rofi prompt widget ("Clipboard"),
// right side is the text field wired to the Clipboard singleton. One-way
// binding: user types → service.query; service resets on refresh → field.
Item {
    id: root
    implicitHeight: 60

    property alias input: field

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 24
        text: "Clipboard"
        color: Theme.accent
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontCaption
            weight:    Font.DemiBold
        }
    }

    TextInput {
        id: field
        anchors.left: label.right
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.fg
        selectionColor: Theme.accent
        selectByMouse: true
        cursorVisible: focus
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontTitle
        }
        text: ""
        onTextChanged: {
            if (Clipboard.query !== text) {
                Clipboard.query = text
                Clipboard.selectedIndex = 0
            }
        }

        // Service → field, fires on refresh() when query is reset.
        Connections {
            target: Clipboard
            function onQueryChanged() {
                if (field.text !== Clipboard.query) field.text = Clipboard.query
            }
        }

        // Navigation + actions. The field owns keyboard focus while the
        // picker is open, so any key that isn't plain text input is routed
        // here first. TextInput swallows only printable chars + Backspace,
        // so Up/Down/Enter/Del/Esc land in this handler.
        Keys.onPressed: (event) => {
            const n = Clipboard.filtered.length
            switch (event.key) {
            case Qt.Key_Escape:
                Clipboard.hide(); event.accepted = true; break
            case Qt.Key_Down:
                if (Clipboard.selectedIndex < n - 1) Clipboard.selectedIndex++
                event.accepted = true; break
            case Qt.Key_Up:
                if (Clipboard.selectedIndex > 0) Clipboard.selectedIndex--
                event.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                Clipboard.pick(Clipboard.selectedIndex)
                event.accepted = true; break
            case Qt.Key_Delete:
                Clipboard.remove(Clipboard.selectedIndex)
                event.accepted = true; break
            case Qt.Key_J:
                if (event.modifiers & Qt.ControlModifier) {
                    if (Clipboard.selectedIndex < n - 1) Clipboard.selectedIndex++
                    event.accepted = true
                }
                break
            case Qt.Key_K:
                if (event.modifiers & Qt.ControlModifier) {
                    if (Clipboard.selectedIndex > 0) Clipboard.selectedIndex--
                    event.accepted = true
                }
                break
            }
        }

        Text {
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            visible: field.text.length === 0
            text: "Search"
            color: Theme.fgDim
            font: field.font
        }
    }
}
