import QtQuick
import Quickshell
import ".."
import "../theme"

// NotificationsPopover — focused popover for the bell pill. Reuses the
// existing NotificationsList for parity with the in-bar-drawer history,
// minus the ControlCenter chrome (clock, toggles, stats). Clicking the
// bell toggles it; outside-click / moving to another monitor dismisses
// via WingPopover's shared plumbing.
//
// Deliberate override on top of the WingPopover default:
//
//   • cardColor = Colors.bgSurface. Lifts the panel one step above the
//     standard `dialogSurface` (== Colors.card == #181b23) so the
//     notification list doesn't read as a black slab next to the
//     adaptive-translucent bar. Items still use `Colors.tileBg` which
//     is a touch brighter, preserving the surface ladder.
//
// bodyHeight: 420px ceiling. Card = header + min(content, 420px) + 2 * padding.
// Empty state provides 200px of presence. Content shorter than 420px → card
// shrinks to fit. Content taller than 420px → card caps and body scrolls.
//
// Header (title + icon + trailing: DND toggle + count text + Clear All) is
// rendered stickily by WingPopover itself. Scrolling the body no longer moves
// the title off the top of the card.
//
// Click-only dismissal (inherited from WingPopover → ArcheDialog):
// click-outside / Esc / monitor-change / another popover-toggle close it.
WingPopover {
    id: root
    popoverId: "notifs"
    name:      "popover-notifs"

    cardWidth:         Sizing.px(380)
    anchorRightMargin: Sizing.px(12)

    cardColor:  Colors.bgSurface
    bodyHeight: Sizing.px(420)

    // ─── Sticky header (first-class WingPopover API) ──────────────────
    title:          "Notifications"
    titleIcon:      ""        // bell
    titleIconColor: Colors.accent

    // Trailing slot: [ DND IconButton ] [ count Text ] [ Clear All ]
    // DND always visible. Count + Clear All hidden when empty.
    trailingComponent: Component {
        Row {
            spacing: Spacing.sm
            readonly property bool isEmpty: Notifs.history.length === 0

            // DND toggle — always visible. Uses bell glyph only (U+F1F6
            // bell-slash is absent in MesloLGS — would CJK-substitute like
            // the U+F6AC WiFi-off bug). Color signals state: accent = active
            // (notifications live), fgDim = DND on.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:  Sizing.px(24)
                height: Sizing.px(24)
                radius: width / 2
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Notifs.dndEnabled ? Colors.fgDim : Colors.accent
                    font.family:    Typography.fontMono
                    font.pixelSize: Typography.fontLabel

                    Behavior on color { CAnim { type: "fast" } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dndEnabled = !Notifs.dndEnabled
                }
            }

            // Count — plain text, no background pill.
            Text {
                visible: !parent.isEmpty
                anchors.verticalCenter: parent.verticalCenter
                text: "(" + Notifs.history.length + ")"
                color: Colors.fgDim
                font {
                    family:    Typography.fontMono
                    pixelSize: Typography.fontMicro
                }
                font.features: ({ "tnum": 1 })
            }

            // Clear All — destructive action, hidden when empty.
            Rectangle {
                id: clearBtn
                visible: !parent.isEmpty
                anchors.verticalCenter: parent.verticalCenter
                width:  Sizing.px(80)
                height: Sizing.px(24)
                radius: height / 2
                color:  clearMouse.containsMouse ? Colors.tileBgActive : Colors.tileBg
                clip:   true

                Behavior on color { CAnim { type: "fast" } }

                Text {
                    anchors.centerIn: parent
                    text: "Clear All"
                    color: Colors.fg
                    font {
                        family: Typography.fontSans
                        pixelSize: Typography.fontCaption
                        weight: Font.Medium
                    }
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearHistory()
                }
            }
        }
    }

    contentComponent: Component {
        NotificationsList {
            width: parent.width
        }
    }
}
