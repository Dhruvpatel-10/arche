import QtQuick
import "../.."

// PickerSearchBar — accent prompt label + text input with picker-wide
// keyboard routing. Private to PickerDialog.
//
// The field owns keyboard focus while the dialog is open, so any key
// that isn't plain text input is routed through here first. TextInput
// swallows only printable chars + Backspace, so Up/Down/Enter/Del/Esc
// land in this handler and fan out to the parent dialog via signals.
Item {
    id: root

    property alias  input:       field
    property alias  text:        field.text
    property string prompt:      ""
    property string placeholder: "Search"

    implicitHeight: 60

    signal textEdited(string text)
    signal navigate(int delta)   // -1 = up, +1 = down
    signal accept()
    signal removeReq()           // "remove" shadows Component.remove()
    signal dismiss()

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 24
        visible: root.prompt.length > 0
        text:  root.prompt
        color: Theme.accent
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontCaption
            weight:    Font.DemiBold
        }
    }

    TextInput {
        id: field
        anchors.left:           label.visible ? label.right : parent.left
        anchors.leftMargin:     label.visible ? 14 : 24
        anchors.right:          parent.right
        anchors.rightMargin:    24
        anchors.verticalCenter: parent.verticalCenter
        color:          Theme.fg
        selectionColor: Theme.accent
        selectByMouse:  true
        cursorVisible:  focus
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontTitle
        }

        onTextChanged: root.textEdited(text)

        Keys.onPressed: (e) => {
            switch (e.key) {
            case Qt.Key_Escape: root.dismiss();     e.accepted = true; break
            case Qt.Key_Down:   root.navigate(+1);  e.accepted = true; break
            case Qt.Key_Up:     root.navigate(-1);  e.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:  root.accept();      e.accepted = true; break
            case Qt.Key_Delete: root.removeReq();   e.accepted = true; break
            case Qt.Key_J:
                if (e.modifiers & Qt.ControlModifier) {
                    root.navigate(+1); e.accepted = true
                }
                break
            case Qt.Key_K:
                if (e.modifiers & Qt.ControlModifier) {
                    root.navigate(-1); e.accepted = true
                }
                break
            }
        }

        Text {
            anchors.fill: parent
            verticalAlignment: TextInput.AlignVCenter
            visible: field.text.length === 0
            text:    root.placeholder
            color:   Theme.fgDim
            font:    field.font
        }
    }
}
