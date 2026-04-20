import QtQuick
import "../.."
import "../../theme"

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
    property bool   loading:     false

    implicitHeight: Sizing.px(60)

    signal textEdited(string text)
    signal navigate(int delta)   // -1 = up, +1 = down
    signal accept()
    signal removeReq()           // "remove" shadows Component.remove()
    signal dismiss()

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Spacing.lg
        visible: root.prompt.length > 0
        text:  root.prompt
        color: Colors.accent
        font {
            family:    Typography.fontSans
            pixelSize: Typography.fontCaption
            weight:    Typography.weightDemiBold
        }
    }

    // Loading spinner — small ring to the right of the input. Only
    // draws + animates while the bar is actually visible and loading,
    // so a closed picker never burns frames on a hidden spinner.
    Rectangle {
        id: spinner
        anchors.right:          parent.right
        anchors.rightMargin:    Spacing.lg
        anchors.verticalCenter: parent.verticalCenter
        width:  Sizing.px(12)
        height: Sizing.px(12)
        radius: width / 2
        color:  "transparent"
        border.color: Colors.fgMuted
        border.width: Shape.borderMd
        opacity: Effects.opacityMuted
        visible: root.loading
        RotationAnimator on rotation {
            from: 0; to: 360; duration: 900; loops: Animation.Infinite
            running: spinner.visible
        }
        // Arc effect via a small bright cap.
        Rectangle {
            width: Sizing.px(4)
            height: Sizing.px(4)
            radius: width / 2
            color: Colors.accent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -1
        }
    }

    TextInput {
        id: field
        anchors.left:           label.visible ? label.right : parent.left
        anchors.leftMargin:     label.visible ? Spacing.md : Spacing.lg
        anchors.right:          spinner.left
        anchors.rightMargin:    Spacing.md
        anchors.verticalCenter: parent.verticalCenter
        color:          Colors.fg
        selectionColor: Colors.accent
        selectByMouse:  true
        cursorVisible:  focus
        font {
            family:    Typography.fontSans
            pixelSize: Typography.fontTitle
        }

        onTextChanged: root.textEdited(text)

        Keys.onPressed: (e) => {
            switch (e.key) {
            case Qt.Key_Escape: root.dismiss();     e.accepted = true; break
            case Qt.Key_Down:   root.navigate(+1);  e.accepted = true; break
            case Qt.Key_Up:     root.navigate(-1);  e.accepted = true; break
            case Qt.Key_Return:
            case Qt.Key_Enter:
                // While an IME is composing (CJK/etc), Enter commits
                // the preedit — don't steal it to accept the picker.
                // Once composition is committed, the next Enter lands
                // here with inputMethodComposing === false.
                if (field.inputMethodComposing) break
                root.accept();      e.accepted = true; break
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
            color:   Colors.fgDim
            font:    field.font
        }
    }
}
