import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import ".."
import "../theme"

// WingPopover — right-wing bar popover shell, delegated to ArcheDialog.
//
// One interaction model across the whole panel: click-to-open, click-
// outside or Esc to dismiss, single instance rendered on the focused
// monitor (MediaPopover / CalendarPanel are the prior art). No cursor-
// leave auto-close — the grace-timer pattern flickers at certain cursor
// positions (card sliding through a stationary cursor during open/close
// races the hit-test) and produces dead-zones where the user's cursor
// is physically over the card but the flag reads false. See
// docs/quickshell-notes.md → "Hover-triggered popovers, retired".
//
// IMPORTANT: we pull in `import QtQuick.Controls` for `ScrollBar`. That
// module exports its own `Dialog` type which would shadow the local one,
// producing "Cannot assign to non-existent property onDismissed" at
// registration. The local base is named `ArcheDialog` precisely to
// sidestep that collision — see ArcheDialog.qml's header.
//
// ─── Sticky header as first-class API ─────────────────────────────────
// Every right-wing popover (notifs / audio / net / bt / battery) used to
// inline the same Row { icon + title } + hairline pattern at the top of
// its contentComponent. Scrolling moved the header with the body, which
// read as "wired" — the title sled off screen under long notif histories
// and long Wi-Fi scan lists.
//
// The fix is architectural, not per-popover: WingPopover now renders the
// header itself, *outside* the internal Flickable, via ArcheDialog's
// `headerComponent` slot. Consumers expose four declarative properties:
//
//   title             — header label (e.g. "Notifications")
//   titleIcon         — nerd-font glyph (e.g. "\uf0f3" for the bell)
//   titleIconColor    — defaults to Colors.accent; override for state-
//                       dependent tinting (NetworkPopover greys the icon
//                       when radio is off).
//   trailingComponent — optional Component rendered flush-right in the
//                       header row (Clear All, count pill, etc.)
//
// `showHeaderDivider` (default true when `title` is set) paints a
// hairline under the header so the boundary with the scroll content is
// always visible. No consumer paints its own divider under the header
// anymore.
//
// Scrollable content. The caller supplies a `contentComponent`
// (a Component, not inline children — a default alias would route
// ArcheDialog's internal scrim / card into the alias target and break the
// surface). The Loader inside the Flickable instantiates it and feeds
// its `implicitHeight` both into the Flickable's `contentHeight` and
// into the natural-card-height chain that ArcheDialog uses to decide how
// tall the card should be.
//
// ─── Sizing contract ──────────────────────────────────────────────────
// ArcheDialog's `contentArea` sits in a ColumnLayout; in popover mode its
// `Layout.preferredHeight` is bound to `childrenRect.height`. The Flickable
// here sets its `height` to min(contentNatural, bodyHeight) — the card
// sizes to content and only caps at bodyHeight when content overflows.
// Card height = header + min(content, bodyHeight) + footer (if any) + 2 * padding.
// When content < bodyHeight the card shrinks to fit, no dead space.
// When content > bodyHeight the Flickable caps at bodyHeight and scrolls.
//
// `fillCardHeight` is deprecated and no longer drives layout. Set `bodyHeight`
// to the desired ceiling instead. `cardMaxHeight` is kept as a safety
// upper bound for ArcheDialog but does not drive the Flickable height.
//
// Usage (single instance in shell.qml — NOT wrapped in Variants):
//
//   WingPopover {
//       popoverId:         "notifs"
//       name:              "popover-notifs"
//       cardWidth:         Sizing.px(380)
//       anchorRightMargin: Sizing.px(12)
//
//       title:     "Notifications"
//       titleIcon: "\uf0f3"
//
//       trailingComponent: Component {
//           Row { /* count pill, Clear All */ }
//       }
//
//       contentComponent: Component {
//           NotificationsList { width: parent.width }
//       }
//   }
ArcheDialog {
    id: root

    // ─── Public API ────────────────────────────────────────────────────
    // Ui.rightPopover value that opens us. Required.
    property string popoverId: ""

    // Legacy alias for ArcheDialog's anchorSideMargin — preserved so the
    // existing popovers keep the same per-popover tuning (e.g. audio
    // pill sits further left than notifs).
    property int anchorRightMargin: Sizing.px(10)

    // Component slot — hosted inside the internal Flickable below.
    property Component contentComponent: null

    // ─── Body sizing (max ceiling) ────────────────────────────────────
    // Maximum body height. Card sizes to content; when content exceeds
    // bodyHeight the body scrolls and the card caps. Use Sizing.px so DPI
    // scales. Design constant — don't bind to reactive expressions.
    property int bodyHeight: Sizing.px(380)

    // ─── Deprecated: fillCardHeight ────────────────────────────────────
    // No longer drives layout. Kept so existing callers don't break.
    property bool fillCardHeight: false
    onFillCardHeightChanged: {
        if (fillCardHeight)
            console.warn("WingPopover: fillCardHeight is deprecated; set bodyHeight instead. (popoverId:", popoverId, ")")
    }

    // ─── Header (sticky, rendered outside the Flickable) ──────────────
    // Empty `title` → no header, no divider, no reserved space.
    property string title: ""
    property string titleIcon: ""
    property color  titleIconColor: Colors.accent
    property Component trailingComponent: null
    // Hairline under the header. Defaults on when a title is set; a
    // consumer can force it off for a chrome-less look.
    property bool showHeaderDivider: title.length > 0

    readonly property bool _hasHeader: title.length > 0

    // ─── Wire into ArcheDialog ─────────────────────────────────────────
    mode:             "popover"
    anchorEdge:       "right"
    anchorSideMargin: anchorRightMargin
    // Click-only dismissal — no cursor-leave timer (explicit default).
    // ArcheDialog already defaults `dismissOnCursorLeave` to false;
    // stating it here makes the interaction model obvious at the call site.
    dismissOnCursorLeave: false

    // Generous default card-height ceiling — tall notification histories
    // want the full screen minus breathing room. `root.height` is the
    // layer window's height; `anchors { top; bottom; left; right }` in
    // ArcheDialog sizes it to the screen.
    cardMaxHeight: Math.max(Sizing.px(240),
                            Math.round((root.height - root.anchorTopMargin)
                                       * 0.82))

    // Open follows the Ui singleton. Every dismissal reason funnels into
    // the same action: clear the global flag. Screen binding comes from
    // ArcheDialog's default (focused monitor) — no per-screen override here.
    open: Ui.rightPopover === popoverId
    onDismissed: Ui.closePopover()

    // ─── Sticky header ─────────────────────────────────────────────────
    // ArcheDialog renders this *above* contentArea inside cardInterior's
    // ColumnLayout. Since the Flickable lives under contentArea, the
    // header stays pinned while the body scrolls.
    //
    // Design: single Row of [icon + title] + optional trailing slot. The
    // icon uses fontLabel (matches pill icons — bar-consistent), title is
    // fontBody / DemiBold (IBM Plex Sans, the UI accent). The divider is
    // a 1px hairline at border opacity 0.4 — quiet enough to read as a
    // structural hint, visible enough to survive the warm-surface step
    // up to `Colors.bgSurface` in NotificationsPopover.
    headerComponent: root._hasHeader ? headerComponentInner : null

    Component {
        id: headerComponentInner
        ColumnLayout {
            spacing: Spacing.sm

            RowLayout {
                Layout.fillWidth: true
                spacing: Spacing.sm

                Text {
                    visible: root.titleIcon.length > 0
                    text:  root.titleIcon
                    color: root.titleIconColor
                    font.family:    Typography.fontMono
                    font.pixelSize: Typography.fontLabel
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color { CAnim { type: "fast" } }
                }

                Text {
                    text:  root.title
                    color: Colors.fg
                    font.family:    Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight:    Typography.weightDemiBold
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Loader {
                    active:  root.trailingComponent !== null
                    visible: active
                    sourceComponent: root.trailingComponent
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Hairline. Sits within contentPadding — we don't bleed to
            // the card edges because the card already has a border and
            // bleeding from inside a Loader fights ColumnLayout's bounds
            // checks. 1px at low opacity is enough separation; the warm
            // surface does the rest of the visual work.
            Rectangle {
                visible: root.showHeaderDivider
                Layout.fillWidth: true
                Layout.preferredHeight: Shape.borderThin
                color: Colors.border
                opacity: Effects.opacitySubtle
            }
        }
    }

    // ─── Card content: scrollable Flickable hosting contentComponent ──
    // Width fills the content area (set via left/right anchors so it
    // respects the contentArea bounds). Height clamps to the lesser of the
    // content's natural height and bodyHeight — so the card collapses to
    // fit sparse content (e.g. 2-slider audio mixer) and caps + scrolls
    // when content overflows (e.g. long notification history).
    Flickable {
        id: flick
        anchors.left:  parent.left
        anchors.right: parent.right

        // why: one derived property → one place to read; avoids duplicating
        // the min() expression across height and implicitHeight.
        readonly property int _natural: contentLoader.item?.implicitHeight ?? 0
        height:        Math.min(_natural, root.bodyHeight)
        implicitHeight: height

        contentWidth:  width
        contentHeight: _natural

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Reset to the top on reopen so returning to a popover lands on
        // the newest item.
        onVisibleChanged: if (visible) contentY = 0

        Loader {
            id: contentLoader
            // Full width — scrollbar overlays the content rather than
            // reserving a gutter. The 3px thumb insets Spacing.xs from the
            // card edge and sits above content visually; at this width it
            // never obscures meaningful text or icons. A fixed gutter would
            // bounce the Loader's layout when content crosses the scroll
            // threshold (oscillation trap, prior comment).
            width: flick.width
            sourceComponent: root.contentComponent
        }

        // ─── Scroll-only thumb ────────────────────────────────────
        // Appears only when content overflows AND the user is actively
        // scrolling. No hover reveal — the HoverHandler pattern caused
        // the bar to appear whenever the cursor entered the right card
        // edge, even with only 2 items that fit the viewport.
        //
        // Visibility gate: `visible: flick.contentHeight > flick.height + 1`
        // removes the element (and its hit region) entirely when content
        // fits. The +1 guards floating-point equality at exact fit.
        //
        // One `_opacity` property → one Behavior → no racing (pitfall #9).
        // Thumb only — no rail. A 2px hairline communicates scroll position
        // without reading as persistent chrome.
        ScrollBar.vertical: ScrollBar {
            id: vbar
            policy: ScrollBar.AsNeeded
            visible: flick.contentHeight > flick.height + 1
            parent: flick
            anchors.top:    flick.top
            anchors.bottom: flick.bottom
            anchors.right:  flick.right
            anchors.rightMargin:  Spacing.xs
            anchors.topMargin:    Spacing.xs
            anchors.bottomMargin: Spacing.xs

            property real _opacity: 0.0
            Behavior on _opacity { Anim { type: "fast" } }

            Timer {
                id: hideTimer
                interval: 800
                repeat:   false
                onTriggered: vbar._opacity = 0.0
            }

            Connections {
                target: flick
                function onMovingChanged() {
                    if (flick.moving) {
                        hideTimer.stop()
                        vbar._opacity = 1.0
                    } else {
                        hideTimer.restart()
                    }
                }
                function onFlickingChanged() {
                    if (flick.flicking) {
                        hideTimer.stop()
                        vbar._opacity = 1.0
                    } else {
                        hideTimer.restart()
                    }
                }
            }

            contentItem: Rectangle {
                implicitWidth: Sizing.px(2)
                radius: Shape.radiusFull
                color: vbar.pressed ? Colors.accent : Colors.fgDim
                opacity: vbar._opacity
                Behavior on color { CAnim { type: "fast" } }
            }

            // No background rail — thumb alone is sufficient when
            // the bar only appears during active scroll.
            background: Item {}
        }
    }
}
