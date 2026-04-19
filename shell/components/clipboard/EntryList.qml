import QtQuick
import Quickshell
import "../.."

// Scrollable entry list. ScriptModel diffs Clipboard.filtered against its
// previous value (keyed by entry id), so the ListView does NOT see a full
// model reset when the query changes — the `currentIndex` binding
// survives (QTBUG-39004 only fires on array-replacement resets) and
// delegates are preserved across filter updates.
//
// Scrolling: keyboard focus lives on the search TextInput, not this
// ListView. Qt's built-in auto-scroll on currentIndex change only fires
// when highlightFollowsCurrentItem is true paired with a highlight item;
// highlightRangeMode: ApplyRange scrolls via the highlight item's
// position, so without one it's a no-op. The delegate already paints
// its own selected background, so adding a dummy highlight rect just to
// coax ApplyRange into scrolling would double-paint. Instead we call
// positionViewAtIndex explicitly — Qt.callLater defers past the
// ScriptModel diff so the target delegate exists (QTBUG-67551).
ListView {
    id: list

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
        values: Clipboard.filtered
        objectProp: "id"
    }

    currentIndex: Clipboard.selectedIndex
    onCurrentIndexChanged: Qt.callLater(() =>
        positionViewAtIndex(currentIndex, ListView.Contain))

    delegate: EntryItem {
        required property var modelData
        required property int index
        width: list.width
        entry: modelData
        selected: ListView.isCurrentItem
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
