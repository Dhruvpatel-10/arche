import QtQuick
import "../.."

// Scrollable entry list. Current row tracks Clipboard.selectedIndex so
// arrow-key nav in the surface and list clicks stay in sync. Empty state
// differentiates "nothing copied yet" from "no search matches".
ListView {
    id: list

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds

    model: Clipboard.filtered
    currentIndex: Clipboard.selectedIndex
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: EntryItem {
        required property var modelData
        required property int index
        width: list.width
        entry: modelData
        selected: index === list.currentIndex
        onActivated: {
            Clipboard.selectedIndex = index
            Clipboard.pick(index)
        }
        onRemoved: Clipboard.remove(index)
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        text: Clipboard.entries.length === 0
            ? "Clipboard is empty"
            : "No matches"
        color: Theme.fgDim
        font { family: Theme.fontSans; pixelSize: Theme.fontBody }
    }
}
