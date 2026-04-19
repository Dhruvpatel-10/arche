import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "./clipboard"

// Clipboard picker. Fullscreen layer-shell surface with a centered modal
// card: search bar on top, entry list on the left, preview pane on the
// right. Unique namespace so the Hyprland blur rule in looknfeel.conf
// picks it up (the generic `quickshell` rule explicitly disables blur).
StyledWindow {
    id: root
    name: "clipboard"

    visible: Clipboard.open
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    // Ignore the bar's exclusive zone so the scrim covers the whole screen.
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // Multi-monitor: close when cursor leaves the screen the picker is on.
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!Clipboard.open) return
            const fm = Hyprland.focusedMonitor
            if (fm && root.screen && fm.name !== root.screen.name)
                Clipboard.hide()
        }
    }

    // Give search focus every time the picker opens.
    onVisibleChanged: {
        if (visible) Qt.callLater(() => searchBar.input.forceActiveFocus())
    }

    // ─── Scrim ─────────────────────────────────────────────────────────
    // Click anywhere outside the card dismisses.
    MouseArea {
        anchors.fill: parent
        onClicked: Clipboard.hide()
    }

    // ─── Modal card ────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  Math.min(960, parent.width  - 80)
        height: Math.min(560, parent.height - 120)
        color: Theme.card
        radius: 14
        border.color: Theme.border
        border.width: 1

        // Swallow clicks on card so the scrim doesn't fire.
        MouseArea { anchors.fill: parent }

        // Subtle entrance.
        opacity: visible ? 1.0 : 0.0
        transform: Translate { id: rise; y: visible ? 0 : 6 }
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            SearchBar {
                id: searchBar
                Layout.fillWidth: true
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
                    Layout.preferredWidth: 360

                    EntryList {
                        anchors.fill: parent
                        anchors.margins: 10
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Theme.border
                    opacity: 0.5
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Preview {
                        anchors.fill: parent
                        anchors.margins: 12
                    }
                }
            }

            // Footer hint strip.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
                opacity: 0.5
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 38

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    spacing: 20

                    Repeater {
                        model: [
                            { k: "↵",   v: "Paste"  },
                            { k: "Del", v: "Remove" },
                            { k: "Esc", v: "Close"  }
                        ]
                        delegate: Row {
                            required property var modelData
                            spacing: 7
                            Text {
                                text: modelData.k
                                color: Theme.fgMuted
                                font { family: Theme.fontMono; pixelSize: Theme.fontCaption }
                            }
                            Text {
                                text: modelData.v
                                color: Theme.fgDim
                                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                            }
                        }
                    }
                }
            }
        }
    }
}
