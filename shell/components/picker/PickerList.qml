import QtQuick
import Quickshell
import "../.."

// PickerList — scroll-safe ListView for the picker base. Private to
// PickerDialog.
//
// ScriptModel diffs `items` against its previous value (keyed by
// `itemIdRole`), so the ListView does NOT see a full model reset when
// the query changes and delegates are preserved across filter updates.
//
// One important caveat: ListView still mutates its own `currentIndex`
// during model churn (row removal/insertion/reorder). Binding
// `currentIndex: selectedIndex` is therefore not stable — an internal
// write can sever the binding and leave `ListView.isCurrentItem`
// highlighting a stale row while the picker's real selection state
// (`selectedIndex`) remains at 0. Keep `selectedIndex` authoritative
// and re-sync ListView's cursor after diffs.
//
// Scrolling: keyboard focus lives on the search TextInput, not this
// ListView. Qt's built-in auto-scroll on currentIndex change only
// fires when highlightFollowsCurrentItem is true paired with a
// highlight item; highlightRangeMode: ApplyRange scrolls via the
// highlight item's position, so without one it's a no-op. The user's
// delegate already paints its own selected background, so adding a
// dummy highlight rect just to coax ApplyRange into scrolling would
// double-paint. Instead _syncCurrentIndex calls positionViewAtIndex
// itself — it always runs inside Qt.callLater (via
// _queueCurrentIndexSync) so the ScriptModel diff has settled and the
// target delegate exists (QTBUG-67551). onCurrentIndexChanged is kept
// lean — drift detection only, positioning is owned by the sync path.
ListView {
    id: list

    property var       items:             []
    property string    itemIdRole:        "id"
    property Component delegateComponent: null
    property int       selectedIndex:     0
    property string    emptyMessage:      ""
    property Component emptyContent:      null
    property bool      _syncQueued:       false

    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
        values:     list.items
        objectProp: list.itemIdRole
    }

    function _targetCurrentIndex() {
        if (list.count === 0 || list.selectedIndex < 0) return -1
        return Math.min(list.selectedIndex, list.count - 1)
    }

    function _syncCurrentIndex() {
        list._syncQueued = false
        const target = list._targetCurrentIndex()
        if (list.currentIndex !== target) list.currentIndex = target
        if (target >= 0)
            positionViewAtIndex(target, ListView.Contain)
    }

    function _queueCurrentIndexSync() {
        if (list._syncQueued) return
        list._syncQueued = true
        Qt.callLater(() => list._syncCurrentIndex())
    }

    Component.onCompleted: list._queueCurrentIndexSync()

    onSelectedIndexChanged: list._queueCurrentIndexSync()
    onCountChanged:         list._queueCurrentIndexSync()

    // Drift detector. Fires on every currentIndex write, including our
    // own writes from _syncCurrentIndex — but a write we just made
    // always matches the target, so the drift branch is a no-op for
    // them. Qt's internal writes during model churn are what this
    // actually catches.
    onCurrentIndexChanged: {
        if (list.currentIndex !== list._targetCurrentIndex())
            list._queueCurrentIndexSync()
    }

    delegate: list.delegateComponent

    // Empty state: prefer the consumer-supplied Component; fall back
    // to the plain message text so simple cases don't need a Component.
    Loader {
        anchors.centerIn: parent
        active: list.count === 0 && list.emptyContent !== null
        visible: active
        sourceComponent: list.emptyContent
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
            && list.emptyContent === null
            && list.emptyMessage.length > 0
        text:    list.emptyMessage
        color:   Theme.fgDim
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontBody
        }
    }
}
