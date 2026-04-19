import QtQuick
import Quickshell
import "../.."

// PickerList — scroll-safe ListView for the picker base. Private to
// PickerDialog.
//
// ScriptModel diffs `items` against its previous value (keyed by
// `itemIdRole`), so the ListView does NOT see a full model reset when
// the query changes — `currentIndex` survives (QTBUG-39004 only fires
// on array-replacement resets) and delegates are preserved across
// filter updates.
//
// Scrolling: keyboard focus lives on the search TextInput, not this
// ListView. Qt's built-in auto-scroll on currentIndex change only
// fires when highlightFollowsCurrentItem is true paired with a
// highlight item; highlightRangeMode: ApplyRange scrolls via the
// highlight item's position, so without one it's a no-op. The user's
// delegate already paints its own selected background, so adding a
// dummy highlight rect just to coax ApplyRange into scrolling would
// double-paint. Instead we call positionViewAtIndex explicitly —
// Qt.callLater defers past the ScriptModel diff so the target delegate
// exists (QTBUG-67551).
ListView {
    id: list

    property var       items:             []
    property string    itemIdRole:        "id"
    property Component delegateComponent: null
    property int       selectedIndex:     0
    property string    emptyMessage:      ""

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
        values:     list.items
        objectProp: list.itemIdRole
    }

    currentIndex: list.selectedIndex
    onCurrentIndexChanged: Qt.callLater(() =>
        positionViewAtIndex(currentIndex, ListView.Contain))

    delegate: list.delegateComponent

    Text {
        anchors.centerIn: parent
        visible: list.count === 0 && list.emptyMessage.length > 0
        text:    list.emptyMessage
        color:   Theme.fgDim
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontBody
        }
    }
}
