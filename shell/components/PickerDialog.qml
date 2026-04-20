import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../theme"
import "./picker"

// PickerDialog — reusable fullscreen layer-shell picker.
//
// Bakes in the scrim, card, search header, scroll-safe list, optional
// right-hand pane, empty-state slot, loading indicator, hover-arming,
// multi-monitor focus binding, and footer hint strip — so consumers
// (clipboard, launcher, power menu) declare only their data, their
// filter or async query hook, and their delegate.
//
// Animation: one `offsetScale` numeric driver (0 = open, 1 = closed)
// feeds both `card.opacity` and `card.transform.y` from the same
// source. The old pattern (Behavior on opacity + simultaneous Translate
// driven by `visible`) desync'd because opacity animated while y snapped
// — trap #9 fixed by collapsing to one driver.
//
// Scroll/selection safety (see fix(clipboard) 866415b): the internal
// ListView keys its ScriptModel on `itemIdRole` so filter updates
// don't cause a full reset (QTBUG-39004), and positionViewAtIndex is
// deferred through Qt.callLater so the target delegate exists by the
// time it runs (QTBUG-67551). Consumers inherit both for free.
//
// ─── Selection preservation ────────────────────────────────────────────
// The old rule — "reset on query change; clamp if out of bounds on
// items change" — broke for async consumers (fzf in-flight, user
// arrow-navigates stale list, results arrive with 6<8 so no clamp
// fires, stale cursor sticks). The new rule tracks the query we last
// intentionally reset at, plus the id we were on before the reset.
// When `items` changes without a corresponding query change
// (background refresh, async fzf delivery), we re-anchor on that id
// and only fall back to 0 if it's gone.
//
// ─── Delegate contract ─────────────────────────────────────────────────
// The Component assigned to `delegate` is expanded by the internal
// ListView; the root Item (usually a PickerItemBase) must declare:
//
//   required property var  modelData   // filtered[index]
//   required property int  index       // index into filtered
//   width: ListView.view.width         // otherwise delegate collapses
//                                      // to 0 and rows paint on top
//                                      // of each other
//
// For highlighting, bind `selected: ListView.isCurrentItem`. Clicks
// on the delegate should call `picker.accept(index)` /
// `picker.remove(index)` — or the no-arg forms which default to
// `selectedIndex`. Keyboard owns selection — hover is visual only
// (pointer cursor on the row); hovering does NOT move selectedIndex.
// See PickerItemBase's header for the reasoning.
StyledWindow {
    id: root

    // ─── Identity ──────────────────────────────────────────────────────
    // Namespaces to "arche-<pickerName>" via StyledWindow. Hyprland
    // layerrules in looknfeel.conf key off this; each picker needs its
    // own name so the blanket `quickshell` blur=0 rule doesn't swallow
    // the scrim.
    name: pickerName
    property string pickerName: "picker"

    // ─── Visibility ────────────────────────────────────────────────────
    // Bind externally — usually to a singleton's `open` flag.
    property bool open: false

    // Single offsetScale driver. 0 = fully visible, 1 = fully hidden.
    // Scrim opacity, card opacity, and card y-translate all derive from
    // it — no racing Behaviors (trap #9).
    property real offsetScale: open ? 0 : 1
    visible: open || offsetScale < 1
    Behavior on offsetScale { Anim { type: "dialog" } }

    // Multi-monitor: render on the currently-focused monitor so
    // invoking the picker via IPC always lands where the user is
    // looking, not on Quickshell.screens[0]. HyprlandMonitor and
    // ShellScreen are separate types — match by `.name` to resolve.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (list[i].name === fm.name) return list[i]
        return null
    }

    // ─── Chrome ────────────────────────────────────────────────────────
    property string prompt:      ""          // accent label left of search
    property string placeholder: "Search"
    property var    hints:       []          // [{k,v}] footer hint pairs

    // ─── Data ──────────────────────────────────────────────────────────
    property var    items:        []
    property string itemIdRole:   "id"       // ScriptModel diff key
    property var    filter:       null       // (item, queryLower) => bool
    property int    maxDisplayed: 0          // post-filter cap; 0 = unbounded

    // ─── Slots ─────────────────────────────────────────────────────────
    property Component delegate:     null    // required — see contract above
    property Component rightPane:    null    // optional preview pane
    property Component emptyContent: null    // optional empty-state view

    // ─── Behavior ──────────────────────────────────────────────────────
    property bool loading:    false          // shows spinner in search bar
    property bool wrapAround: false          // nav wraps past top/bottom

    property bool preserveSelectionOnItemsChange: true

    // ─── Layout ────────────────────────────────────────────────────────
    property int maxWidth:      480
    property int maxHeight:     560
    property int leftPaneWidth: 360         // only used when rightPane set

    // ─── State (owned locally) ─────────────────────────────────────────
    property string query:         ""
    property int    selectedIndex: 0

    readonly property var filtered: _computeFiltered()
    readonly property var selected:
        (filtered.length > 0 && selectedIndex >= 0
                             && selectedIndex < filtered.length)
            ? filtered[selectedIndex] : null

    // ─── Signals ───────────────────────────────────────────────────────
    signal accepted(int index, var item)
    signal removed(int index, var item)
    signal dismissed()
    signal selectionChanged(int index, var item)

    // ─── Public actions ────────────────────────────────────────────────
    function accept(index) {
        const i = (index === undefined) ? selectedIndex : index
        if (i < 0 || i >= filtered.length) return
        root.accepted(i, filtered[i])
    }

    function remove(index) {
        const i = (index === undefined) ? selectedIndex : index
        if (i < 0 || i >= filtered.length) return
        root.removed(i, filtered[i])
    }

    function dismiss() { root.dismissed() }

    function moveSelection(delta) {
        const n = filtered.length
        if (n === 0) return
        let next = selectedIndex + delta
        if (wrapAround) {
            next = ((next % n) + n) % n
        } else if (next < 0 || next >= n) {
            return
        }
        selectedIndex = next
    }

    // ─── Selection preservation internals ──────────────────────────────
    property var _lastSelectedId: undefined

    onSelectedChanged: {
        if (selected) _lastSelectedId = selected[itemIdRole]
        root.selectionChanged(selectedIndex, selected)
    }

    onQueryChanged: selectedIndex = 0

    onItemsChanged: {
        if (preserveSelectionOnItemsChange && _lastSelectedId !== undefined) {
            const idKey = itemIdRole
            const i = filtered.findIndex(it => it && it[idKey] === _lastSelectedId)
            if (i >= 0) { selectedIndex = i; return }
        }
        // Fallthrough: either preservation is off (async consumer:
        // every items refresh comes from a keystroke, so fresh results
        // mean fresh cursor), or the anchored id no longer exists in
        // the new list. Either way, snap to top. Keeping the old index
        // blindly when it's coincidentally in-bounds is what caused
        // "typed `you`, cursor on mpv" — the old list's row 2 happened
        // to fit inside the new 3-row result.
        selectedIndex = 0
    }

    // ─── Internals ─────────────────────────────────────────────────────
    function _computeFiltered() {
        if (!items) return []
        let result = items
        if (query && filter) {
            const q = query.toLowerCase()
            result = items.filter(i => filter(i, q))
        }
        if (maxDisplayed > 0 && result.length > maxDisplayed)
            result = result.slice(0, maxDisplayed)
        return result
    }

    // ─── Geometry ──────────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Multi-monitor: close when the focused monitor changes.
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!root.open) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                root.dismiss()
        }
    }

    // Reset transient state + grab search focus every time the picker
    // opens. Matches the rofi muscle memory: reopening starts on row
    // 0 with an empty query, not whatever the user last filtered to.
    onVisibleChanged: {
        if (visible) {
            query = ""
            selectedIndex = 0
            _lastSelectedId = undefined
            Qt.callLater(() => searchBar.input.forceActiveFocus())
        }
    }

    // ─── Scrim ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.dialogScrim
        opacity: 1 - root.offsetScale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  Math.min(root.maxWidth,  parent.width  - Spacing.dialogInset * 2)
        height: Math.min(root.maxHeight, parent.height - Spacing.dialogInset * 2)
        color: Colors.dialogSurface
        radius: Shape.radiusDialog
        border.color: Colors.dialogBorder
        border.width: Shape.borderThin

        // Both opacity and y-translate driven by the single offsetScale.
        // No separate Behavior on opacity or y — trap #9.
        opacity: 1 - root.offsetScale
        transform: Translate { y: root.offsetScale * Sizing.px(8) }

        // Swallow clicks on the card so the scrim doesn't fire.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PickerSearchBar {
                id: searchBar
                Layout.fillWidth: true
                prompt:      root.prompt
                placeholder: root.placeholder
                text:        root.query
                loading:     root.loading && root.visible
                onTextEdited: (t) => { if (root.query !== t) root.query = t }
                onNavigate:  (delta) => root.moveSelection(delta)
                onAccept:    root.accept(root.selectedIndex)
                onRemoveReq: root.remove(root.selectedIndex)
                onDismiss:   root.dismiss()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.dialogBorder
                opacity: 0.5
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth:  !root.rightPane
                    Layout.preferredWidth: root.rightPane ? root.leftPaneWidth : 0

                    PickerList {
                        anchors.fill: parent
                        anchors.margins: Spacing.md
                        items:             root.filtered
                        itemIdRole:        root.itemIdRole
                        delegateComponent: root.delegate
                        selectedIndex:     root.selectedIndex
                        emptyContent:      root.emptyContent
                        emptyMessage: root.items.length === 0
                            ? "No items"
                            : "No matches"
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    visible: !!root.rightPane
                    color: Colors.dialogBorder
                    opacity: 0.5
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !!root.rightPane
                    active:  !!root.rightPane
                    sourceComponent: root.rightPane
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                visible: root.hints.length > 0
                color: Colors.dialogBorder
                opacity: 0.5
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Sizing.px(38)
                visible: root.hints.length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Spacing.lg
                    spacing: Spacing.xl

                    Repeater {
                        model: root.hints
                        delegate: Row {
                            required property var modelData
                            spacing: Spacing.sm
                            Text {
                                text:  modelData.k
                                color: Colors.fgMuted
                                font {
                                    family:    Typography.fontMono
                                    pixelSize: Typography.fontCaption
                                }
                            }
                            Text {
                                text:  modelData.v
                                color: Colors.fgDim
                                font {
                                    family:    Typography.fontSans
                                    pixelSize: Typography.fontCaption
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
