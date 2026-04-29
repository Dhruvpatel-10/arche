import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../theme"

// ArcheDialog — unified base for every dialog and popover surface in the
// shell.
//
// Named "ArcheDialog" (not "Dialog") on purpose. QtQuick.Controls ships
// its own `Dialog` type. Any consumer that imports `QtQuick.Controls`
// (WingPopover pulls it in for `ScrollBar`; MediaPopover / AudioMixerPopover
// for other Controls types) would otherwise resolve bare `Dialog { ... }`
// to `QtQuick.Controls.Dialog` — which has no `dismissed` signal —
// producing a misleading "Cannot assign to non-existent property
// onDismissed" at type-registration. The rename sidesteps the collision
// permanently; no consumer has to think about import ordering.
//
// ONE PLACE to learn the pitfall-coverage pattern. Two modes cover nearly
// every overlay we'd ever want to render: centered modals and anchored
// popovers. Pickers and the media card stay as specialized surfaces for
// now; this base is the starting point for all new work, and the target
// that StyledDialog/WingPopover delegate to.
//
// ─── Pitfall coverage ─────────────────────────────────────────────────
// #1 parallel geometry ...... single card Rectangle; one radius constant
// #3 input masking .......... full-screen layer; scrim catches outside
//                             clicks without swallowing them elsewhere;
//                             card.MouseArea swallows in-card clicks so
//                             the scrim dismiss doesn't fire
// #6 namespace-as-binding ... `name` is forwarded to WlrLayershell at
//                             construction via StyledWindow's attached
//                             property — never mutated at runtime
// #7 default-namespace ...... `name` is required (empty name → runtime
//                             warning) so no dialog ever falls to the
//                             default `quickshell` namespace
// #9 racing Behaviors ....... single `offsetScale` numeric driver
//                             (0 = open, 1 = closed). Scrim opacity,
//                             card opacity, and card y-translate all
//                             derive from it. The ONLY Behavior is on
//                             offsetScale itself
// #11 single-instance ........ documented on the consumer — wrap in
//                             `Variants { model: Quickshell.screens }`
//                             for per-screen popovers
//
// ─── Modes ─────────────────────────────────────────────────────────────
// "modal" (default):
//     • Centered on the focused monitor.
//     • Full-screen scrim dims the desktop behind (Colors.dialogScrim).
//     • Keyboard focus is Exclusive — dialog owns input.
//     • Card opacity + slight y-translate on enter/exit.
//     • Dismissal: Esc, scrim click, monitor-change, caller-driven.
//     • Consumers: confirmations (PowerMenu), settings sheets, anything
//       that stops the rest of the UI cold.
//
// "popover":
//     • Anchored to a screen edge (top-right for bar wings, top-left
//       for media card, top-center for the calendar).
//     • Transparent scrim (configurable) — click-outside dismisses;
//       clicks on other monitors stay live.
//     • Keyboard focus is OnDemand — popover doesn't steal focus.
//     • Card slides in from above its anchor on open.
//     • Animation: `"spatial"` (500 ms, expressive spatial with gentle
//       overshoot) — the "alive" arrival the calendar established. Modals
//       stay on the calmer `"dialog"` curve by design (no bounce on a
//       destructive confirmation).
//     • Dismissal: Esc, click-outside, monitor-change, optional
//       cursor-leave grace timer.
//     • Consumers: right-wing bar popovers (notifs/audio/net/bt/batt),
//       media card, calendar, anywhere a transient surface hangs off a
//       trigger.
//
// ─── Public API ────────────────────────────────────────────────────────
// Required:
//   name              unique Hyprland namespace suffix ("notifs" →
//                     "arche-notifs"). Keep it specific so layerrules
//                     in hyprland.conf don't cross-match.
//   open              binding to a singleton flag (Ui.*, Launcher.*, …)
//
// Layout:
//   mode              "modal" | "popover" (default: "modal")
//   cardWidth         int; popover uses this, modal caps at maxWidth
//   cardMaxWidth      int; modal only
//   cardMaxHeight     int; caps card height (both modes)
//   anchorEdge        "right" | "left" | "center" (popover only, default
//                     "right"). "center" horizontally centers the card
//                     under the top edge (CalendarPanel's pattern);
//                     `anchorSideMargin` is ignored in that case.
//   anchorSideMargin  int; popover distance from anchorEdge
//                     (ignored when anchorEdge is "center")
//   anchorTopMargin   int; popover distance from the top edge of the
//                     layer window (which is full-screen — anchors
//                     top+bottom+left+right). Default
//                     `Sizing.barHeight + Spacing.xs` so the card hangs
//                     directly below the bar without the consumer having
//                     to opt in — every arche popover lives under the
//                     bar, there's no case where one sits at the screen
//                     top. Override only for deliberate special cases.
//
// Chrome:
//   contentPadding    int; inner padding around content (default
//                     Spacing.dialogPad == 16px). Use 0 for full-bleed.
//   cardRadius        int; corner radius (default Shape.radiusDialog)
//   scrimOpacity      real 0..1; 1 = full dim (modal default),
//                     0 = transparent (popover default)
//
// Behavior:
//   exclusiveFocus    bool; true = modal default, false = popover
//                     default. Modals own keyboard; popovers don't.
//   dismissOnCursorLeave  bool; popover only. If true, a grace timer
//                     fires when the cursor leaves the card.
//   cursorLeaveGraceMs    int; grace period for that timer.
//   dismissOnMonitorChange  bool; default true. Closes when the
//                     focused monitor changes away.
//
// Content slot:
//   Default alias — children of the ArcheDialog go inside the card, under
//   the optional header/footer. The card is a ColumnLayout so content
//   items stack vertically; inside them, use Layout.fillWidth/Height
//   as needed. For scrollable content, embed your own Flickable.
//
//   Component slots:
//     headerComponent   Optional Component rendered at card top.
//     footerComponent   Optional Component rendered at card bottom.
//
// ─── Signals ───────────────────────────────────────────────────────────
//   dismissed()         Parameterless. Fires on every exit path. The
//                       reason ("outside" | "esc" | "monitor-left" |
//                       "cursor-left" | "commit" | "cancel" | "action")
//                       is stashed on the `dismissReason` property just
//                       before emit, so consumers that care can read
//                       `root.dismissReason` inside their handler.
//
//                       Why parameterless: QML-file → QML-file signal
//                       inheritance drops parameterized signals in
//                       Quickshell's Qt version — `onDismissed` on a
//                       subclass fails registration with "Cannot assign
//                       to non-existent property". PickerDialog's
//                       `signal dismissed()` works; ArcheDialog mirrors it.
//
//                       The consumer flips its open flag in response.
//                       ArcheDialog doesn't mutate `open` on its own —
//                       the flag always lives on the consumer's singleton.
//
// ─── Example: modal ────────────────────────────────────────────────────
//   ArcheDialog {
//       name: "powermenu-confirm"
//       mode: "modal"
//       open: PowerMenu.confirmOpen
//       cardMaxWidth:  Sizing.px(380)
//       cardMaxHeight: Sizing.px(220)
//       onDismissed: {
//           if (root.dismissReason === "action") PowerMenu.confirm()
//           else                                 PowerMenu.cancel()
//       }
//
//       Text {
//           Layout.fillWidth: true
//           text: "Sign out?"
//           color: Colors.fg
//           font.family: Typography.fontSans
//           font.pixelSize: Typography.fontTitle
//           font.weight: Typography.weightDemiBold
//       }
//       // ... body text, buttons row
//   }
//
// ─── Example: popover ──────────────────────────────────────────────────
//   ArcheDialog {
//       name: "popover-notifs"
//       mode: "popover"
//       open: Ui.rightPopover === "notifs"
//       cardWidth: Sizing.px(380)
//       anchorEdge: "right"
//       anchorSideMargin: Sizing.px(12)
//       onDismissed: Ui.closePopover()
//
//       NotificationsList { Layout.fillWidth: true }
//   }
StyledWindow {
    id: root

    // ─── Required ──────────────────────────────────────────────────────
    // `name` is forwarded to StyledWindow's WlrLayershell.namespace at
    // construction. Empty → "arche-shell" (trap #7). Keep it unique.
    // property string name — inherited from StyledWindow

    property bool open: false

    // ─── Mode ──────────────────────────────────────────────────────────
    property string mode: "modal"
    readonly property bool _isModal:   mode === "modal"
    readonly property bool _isPopover: mode === "popover"

    // ─── Layout ────────────────────────────────────────────────────────
    property int cardWidth:     Sizing.px(400)
    property int cardMaxWidth:  Sizing.px(480)
    property int cardMaxHeight: Sizing.px(560)

    // Popover anchor — ignored in modal mode. "center" horizontally
    // centers the card and ignores `anchorSideMargin` (CalendarPanel's
    // pattern). Top margin defaults to `Sizing.barHeight + Spacing.xs`
    // so every popover slides in directly under the bar by default — the
    // layer window is full-screen (top+bottom+left+right), so a bare
    // `Spacing.xs` (4 px) would land the card on top of the bar. All
    // arche popovers live under the bar; consumers override this only
    // for deliberate special cases.
    property string anchorEdge:       "right"    // "right" | "left" | "center"
    property int    anchorSideMargin: Sizing.px(12)
    property int    anchorTopMargin:  Sizing.barHeight + Spacing.xs

    // ─── Chrome ────────────────────────────────────────────────────────
    property int  contentPadding: Spacing.dialogPad
    property int  cardRadius:     Shape.radiusDialog
    // Card fill color — defaults to the shared dialogSurface token so every
    // dialog and popover reads as the same surface class. Consumers can
    // override to lift a specific popover one step (e.g. NotificationsPopover
    // uses `Colors.bgSurface` so the list reads less "black slab" against
    // the darker desktop chrome). Don't reach for a raw hex — pick another
    // role from theme/Colors.qml.
    property color cardColor:     Colors.dialogSurface
    // Scrim opacity defaults: modal full-dim, popover transparent catcher.
    property real scrimOpacity:   _isModal ? 1.0 : 0.0

    // ─── Behavior ──────────────────────────────────────────────────────
    property bool exclusiveFocus: _isModal
    property bool dismissOnCursorLeave: false
    property int  cursorLeaveGraceMs:   1500
    property bool dismissOnMonitorChange: true

    // ─── Slots ─────────────────────────────────────────────────────────
    // Default alias: direct children land inside the card's content area
    // (under optional header, above optional footer). Content is laid out
    // in a ColumnLayout — use Layout.fillWidth on items that should span.
    default property alias content: contentArea.data

    property Component headerComponent: null
    property Component footerComponent: null

    // ─── Measured chrome heights ───────────────────────────────────────
    // Exposed so consumers can size internal scrollable content to fit
    // under a sticky header / above a sticky footer. The Flickable inside
    // WingPopover reads these to avoid overflowing the card when a
    // `fillCardHeight`-style popover pins itself to `cardMaxHeight`.
    //
    // Each value includes the ColumnLayout spacing between that chrome
    // slot and the content area, so the subtraction is direct:
    //     usable = cardMaxHeight - 2*contentPadding
    //              - headerSectionHeight - footerSectionHeight
    readonly property int headerSectionHeight:
        headerLoader.active && headerLoader.item
            ? headerLoader.item.height + cardInterior.spacing
            : 0
    readonly property int footerSectionHeight:
        footerLoader.active && footerLoader.item
            ? footerLoader.item.height + cardInterior.spacing
            : 0

    // ─── Signals ───────────────────────────────────────────────────────
    // Parameterless signal with a separate `dismissReason` property.
    //
    // HISTORY: we tried `signal dismissed(string reason)` (legacy) and
    // `signal dismissed(reason: string)` (QML 6 typed form); both
    // *compile* but subclasses get a registration error —
    // "Cannot assign to non-existent property onDismissed" — because the
    // QML-file-based type system fails to propagate parameterized signals
    // from a QML-defined base to its QML-defined subclass in Quickshell's
    // Qt version. PickerDialog (parameterless `signal dismissed()`)
    // works fine, so we mirror that pattern here. Consumers read
    // `dismissReason` right before `onDismissed` fires — the internal
    // `_emitDismissal(reason)` helper sets the property before emit
    // so the reason is observable by the time the handler runs.
    signal dismissed()
    property string dismissReason: ""
    function _emitDismissal(reason) {
        dismissReason = reason
        dismissed()
    }

    // ─── Multi-monitor target ──────────────────────────────────────────
    // Modals default to the focused monitor so `qs ipc call` from a
    // keybind always lands where the user is looking. Popovers are
    // per-screen — consumers wrap this type in a Variants block and set
    // `screen: modelData` themselves; that binding overrides this one.
    //
    // NOTE: a ternary that returns `root.screen` from one branch creates
    // a binding loop (the property depends on itself). Instead we
    // compute the focused-monitor screen unconditionally here; consumers
    // override with their own `screen:` in popover mode, which wins.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (list[i].name === fm.name) return list[i]
        return null
    }

    // ─── Geometry ──────────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: exclusiveFocus
                                    ? WlrKeyboardFocus.Exclusive
                                    : WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // ─── Animation driver (single numeric) ─────────────────────────────
    // 0 = fully open, 1 = fully closed. Scrim opacity + card opacity +
    // card y-translate all derive from this. No racing Behaviors (#9).
    //
    // Animation type picks the right feel for the mode. Popovers use the
    // expressive spatial curve (500 ms, gentle overshoot y=1.21) — the
    // "alive" arrival CalendarPanel established, matching how the
    // ControlCenter drawer lands. Modals stay on the calm "dialog" curve
    // (200 ms, standard easing, no overshoot) — a destructive confirmation
    // should not bounce.
    property real offsetScale: open ? 0 : 1
    visible: open || offsetScale < 1
    Behavior on offsetScale {
        Anim { type: root._isPopover ? "spatial" : "dialog" }
    }

    // ─── Dismissal: monitor change ─────────────────────────────────────
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!root.open) return
            if (!root.dismissOnMonitorChange) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                root._emitDismissal("monitor-left")
        }
    }

    // ─── Dismissal: Esc key ────────────────────────────────────────────
    // FocusScope pulls the OnDemand/Exclusive focus while open.
    FocusScope {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: root._emitDismissal("esc")
    }

    // ─── Dismissal: cursor-leave (popover only) ────────────────────────
    Timer {
        id: leaveTimer
        interval: root.cursorLeaveGraceMs
        onTriggered: {
            if (root.dismissOnCursorLeave) root._emitDismissal("cursor-left")
        }
    }

    // ─── Scrim ─────────────────────────────────────────────────────────
    // One fill + one click-catcher. The fill's opacity crossfades with
    // offsetScale; its peak alpha is set by scrimOpacity.
    Rectangle {
        anchors.fill: parent
        color: Colors.dialogScrim
        // Modal: scrimOpacity=1 × (1-offsetScale). Popover: scrimOpacity=0
        // → the rectangle paints transparent and only the sibling
        // MouseArea catches the outside click.
        opacity: root.scrimOpacity * (1 - root.offsetScale)
    }

    MouseArea {
        anchors.fill: parent
        // Left-button only — right-clicks on a popover's transparent
        // catcher should fall through to the underlying window.
        acceptedButtons: root._isPopover ? Qt.LeftButton : Qt.AllButtons
        onClicked: root._emitDismissal("outside")
    }

    // ─── Card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card

        // Geometry differs by mode. Modal: centered, size capped to
        // maxWidth/maxHeight with inset padding from the screen edges.
        // Popover: anchored to an edge, width is cardWidth, height is
        // content-natural capped at cardMaxHeight.
        //
        // Popover anchors use anchors.top + anchorTopMargin (with the
        // offsetScale-derived slide-in offset) and the side anchor
        // picked by anchorEdge.
        width: root._isModal
               ? Math.min(root.cardMaxWidth,
                          parent.width - Spacing.dialogInset * 2)
               : root.cardWidth
        height: root._isModal
                ? Math.min(root.cardMaxHeight,
                           parent.height - Spacing.dialogInset * 2)
                : Math.min(cardInterior.implicitHeight + root.contentPadding * 2,
                           root.cardMaxHeight)

        // Positioning: centerIn for modal; anchored for popover.
        //
        // Slide offset — when closed (offsetScale=1) the card sits
        // `card.height + Spacing.sm` above its rest position, so the
        // fade+slide lands flush with anchorTopMargin. 6 px (Spacing.sm)
        // matches the calendar's long-standing feel — tight enough that
        // the overshoot settle isn't fighting extra air, loose enough that
        // the card clears the bar edge cleanly.
        anchors.centerIn: root._isModal ? parent : undefined
        anchors.top: root._isPopover ? parent.top : undefined
        anchors.topMargin: root._isPopover
            ? root.anchorTopMargin
              + (-card.height - Spacing.sm) * root.offsetScale
            : 0
        anchors.right: (root._isPopover && root.anchorEdge === "right")
                       ? parent.right : undefined
        anchors.rightMargin: (root._isPopover && root.anchorEdge === "right")
                             ? root.anchorSideMargin : 0
        anchors.left: (root._isPopover && root.anchorEdge === "left")
                      ? parent.left : undefined
        anchors.leftMargin: (root._isPopover && root.anchorEdge === "left")
                            ? root.anchorSideMargin : 0
        anchors.horizontalCenter:
            (root._isPopover && root.anchorEdge === "center")
                ? parent.horizontalCenter : undefined

        color:        root.cardColor
        radius:       root.cardRadius
        border.color: Colors.dialogBorder
        border.width: Shape.borderThin
        clip:         true

        // Modal: opacity fade + subtle 8px y-lift on enter/exit.
        // Popover: opacity fade only — the topMargin binding above
        // handles the slide, so no Translate transform here (stacking
        // them would visually double up the y-motion).
        opacity: 1 - root.offsetScale
        transform: Translate {
            y: root._isModal ? root.offsetScale * Sizing.px(8) : 0
        }

        // In-card clicks stay in the card — don't leak to the scrim's
        // click-outside handler. Popover's cursor-leave timer also
        // resets here via a HoverHandler sibling (below).
        MouseArea { anchors.fill: parent }

        // Cursor-leave grace timer — popover only. Declared inside the
        // card so enter/exit events line up with the visible surface.
        HoverHandler {
            enabled: root._isPopover && root.dismissOnCursorLeave
            onHoveredChanged: {
                if (hovered) leaveTimer.stop()
                else         leaveTimer.restart()
            }
        }

        // Card interior — optional header / content / optional footer,
        // stacked by a ColumnLayout. Its `implicitHeight` feeds the
        // popover card height binding (modal mode ignores it — modals
        // are bounded by cardMaxHeight).
        //
        // `contentArea` is a plain Item (not a layout) so consumers can
        // parent their own ColumnLayout / Column / anchors-based content
        // without fighting a wrapping Layout contract. Its height binds
        // to `childrenRect.height` in popover mode (content-natural) and
        // to the remaining card space in modal mode (fill).
        ColumnLayout {
            id: cardInterior
            anchors.fill: parent
            anchors.margins: root.contentPadding
            spacing: Spacing.dialogContentGap

            // Header slot.
            Loader {
                id: headerLoader
                Layout.fillWidth: true
                active:  root.headerComponent !== null
                visible: active
                sourceComponent: root.headerComponent
            }

            // Default alias target — consumer content lives here.
            Item {
                id: contentArea
                Layout.fillWidth: true
                // Modal: fill remaining card height (consumers use
                // `anchors.fill: parent` on their own layout).
                // Popover: shrink to natural child height.
                Layout.fillHeight: root._isModal
                Layout.preferredHeight: root._isModal
                    ? -1
                    : contentArea.childrenRect.height
            }

            // Footer slot.
            Loader {
                id: footerLoader
                Layout.fillWidth: true
                active:  root.footerComponent !== null
                visible: active
                sourceComponent: root.footerComponent
            }
        }
    }
}
