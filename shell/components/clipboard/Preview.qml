import QtQuick
import QtQuick.Controls
import "../.."

// Right-hand preview pane. Shows the full content of the selected
// entry: decoded image (cache: false so same-id redecodes refresh) for
// binary, full text for anything else. Three empty states — no
// selection, image still decoding, and no entries at all — so the pane
// never looks broken.
Rectangle {
    id: root

    // Fed by ClipboardPicker from PickerDialog.selected; may be null
    // when the list is empty or filtered to nothing.
    property var entry: null

    // Total entries in the clipboard (not filtered). Passed down by
    // ClipboardPicker so this component doesn't need to reach into
    // the Clipboard singleton itself — keeps the preview pane pure
    // view, re-usable with any future entry source.
    property int entryCount: 0

    color: Qt.rgba(0, 0, 0, 0.22)
    radius: 10
    clip: true

    // ─── Image ─────────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        anchors.margins: 18
        visible: root.entry && root.entry.isImage && root.entry.imagePath
        source: (root.entry && root.entry.imagePath)
            ? "file://" + root.entry.imagePath
            : ""
        fillMode:     Image.PreserveAspectFit
        asynchronous: true
        cache:        false
        smooth:       true
        mipmap:       true
    }

    // ─── Text ──────────────────────────────────────────────────────────
    ScrollView {
        anchors.fill: parent
        anchors.margins: 18
        visible: root.entry && !root.entry.isImage
        clip: true

        TextArea {
            readOnly: true
            wrapMode: TextEdit.Wrap
            background: null
            selectByMouse: true
            text: (root.entry && root.entry.decodedText !== null)
                ? root.entry.decodedText
                : (root.entry ? root.entry.preview : "")
            color: Theme.fg
            font { family: Theme.fontMono; pixelSize: Theme.fontBody }
        }
    }

    // ─── Status labels ─────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: !root.entry
        text: root.entryCount === 0
            ? "Nothing copied yet"
            : "Preview"
        color: Theme.fgDim
        font { family: Theme.fontSans; pixelSize: Theme.fontBody }
    }

    Text {
        anchors.centerIn: parent
        visible: root.entry && root.entry.isImage && !root.entry.imagePath
        text: "Decoding…"
        color: Theme.fgDim
        font { family: Theme.fontSans; pixelSize: Theme.fontBody }
    }
}
