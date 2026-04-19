import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "./picker"

// PickerDialog — reusable fullscreen layer-shell picker.
//
// Bakes in the scrim, card, search header, scroll-safe list, optional
// right-hand pane, and footer hint strip that the clipboard picker
// pioneered — so future dialogs (power menu, launcher, window switcher,
// keybindings help) can drop the rofi dependency without re-deriving
// geometry, keyboard routing, or the QTBUG scroll fix.
//
// Scroll/selection safety (see fix(clipboard) 866415b): the internal
// ListView keys its ScriptModel on `itemIdRole` so filter updates don't
// cause a full reset (QTBUG-39004), and positionViewAtIndex is deferred
// through Qt.callLater so the target delegate exists by the time it
// runs (QTBUG-67551). Consumers inherit both for free.
//
// Delegate contract — the Component assigned to `delegate` is expanded
// by the internal ListView; the root Item must declare:
//
//   required property var  modelData   // filtered[index]
//   required property int  index       // index into filtered
//   width: ListView.view.width         // stretch to list — otherwise the
//                                      // delegate collapses to 0 and the
//                                      // contents paint on top of each other
//
// For highlighting, bind `selected: ListView.isCurrentItem`. Clicks
// should call `picker.accept(index)` / `picker.remove(index)` on the
// PickerDialog's outer id — inline delegate Components inherit their
// declaration scope, so the id resolves without any wiring.
//
// Example:
//
//   PickerDialog {
//       id: picker
//       pickerName: "power"
//       prompt: "Power"
//       items: PowerMenu.actions
//       filter: (it, q) => it.label.toLowerCase().includes(q)
//       onAccepted:  (i, item) => PowerMenu.run(item)
//       onDismissed: PowerMenu.hide()
//       delegate: PowerMenuItem {
//           required property var modelData
//           required property int index
//           action: modelData
//           selected: ListView.isCurrentItem
//           onActivated: picker.accept(index)
//       }
//   }
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
    visible: open
    property bool open: false

    // ─── Chrome ────────────────────────────────────────────────────────
    property string prompt:      ""          // accent label left of search
    property string placeholder: "Search"
    property var    hints:       []          // [{k,v}] footer hint pairs

    // ─── Data ──────────────────────────────────────────────────────────
    property var    items:      []
    property string itemIdRole: "id"         // ScriptModel diff key
    property var    filter:     null         // (item, queryLower) => bool

    // ─── Slots ─────────────────────────────────────────────────────────
    property Component delegate:   null      // required — see contract above
    property Component rightPane:  null      // optional preview pane

    // ─── Layout ────────────────────────────────────────────────────────
    property int maxWidth:       480
    property int maxHeight:      560
    property int leftPaneWidth:  360         // only used when rightPane set

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
        const next = selectedIndex + delta
        if (next < 0 || next >= n) return
        selectedIndex = next
    }

    // ─── Internals ─────────────────────────────────────────────────────
    function _computeFiltered() {
        if (!items) return []
        if (!query || !filter) return items
        const q = query.toLowerCase()
        return items.filter(i => filter(i, q))
    }

    onQueryChanged: selectedIndex = 0
    onItemsChanged: if (selectedIndex >= filtered.length) selectedIndex = 0
    onSelectedChanged: root.selectionChanged(selectedIndex, selected)

    // ─── Geometry ──────────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Ignore the bar's exclusive zone so the scrim covers the whole screen.
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Multi-monitor: close when the cursor leaves the screen the picker is on.
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!root.open) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                root.dismiss()
        }
    }

    // Reset transient state + grab search focus every time the picker opens.
    // Matches the rofi muscle memory: reopening starts on row 0 with an
    // empty query, not whatever the user last filtered to.
    onVisibleChanged: {
        if (!visible) return
        query = ""
        selectedIndex = 0
        Qt.callLater(() => searchBar.input.forceActiveFocus())
    }

    // ─── Scrim ─────────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  Math.min(root.maxWidth,  parent.width  - 80)
        height: Math.min(root.maxHeight, parent.height - 120)
        color: Theme.card
        radius: Theme.radius
        border.color: Theme.border
        border.width: 1

        // Swallow clicks on the card so the scrim doesn't fire.
        MouseArea { anchors.fill: parent }

        // Subtle entrance.
        opacity: root.visible ? 1.0 : 0.0
        transform: Translate { y: root.visible ? 0 : 6 }
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PickerSearchBar {
                id: searchBar
                Layout.fillWidth: true
                prompt:      root.prompt
                placeholder: root.placeholder
                text:        root.query
                onTextEdited: (t) => { if (root.query !== t) root.query = t }
                onNavigate:  (delta) => root.moveSelection(delta)
                onAccept:    root.accept(root.selectedIndex)
                onRemoveReq: root.remove(root.selectedIndex)
                onDismiss:   root.dismiss()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
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
                        anchors.margins: 10
                        items:             root.filtered
                        itemIdRole:        root.itemIdRole
                        delegateComponent: root.delegate
                        selectedIndex:     root.selectedIndex
                        emptyMessage: root.items.length === 0
                            ? "No items"
                            : "No matches"
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    visible: !!root.rightPane
                    color: Theme.border
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
                color: Theme.border
                opacity: 0.5
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                visible: root.hints.length > 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    spacing: 20

                    Repeater {
                        model: root.hints
                        delegate: Row {
                            required property var modelData
                            spacing: 7
                            Text {
                                text:  modelData.k
                                color: Theme.fgMuted
                                font {
                                    family:    Theme.fontMono
                                    pixelSize: Theme.fontCaption
                                }
                            }
                            Text {
                                text:  modelData.v
                                color: Theme.fgDim
                                font {
                                    family:    Theme.fontSans
                                    pixelSize: Theme.fontCaption
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
