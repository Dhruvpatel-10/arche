import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."
import "../theme"

// PowerMenuConfirm — confirms destructive power actions (reboot, shutdown).
//
// Opened by PowerMenu.run(action) when action.danger === true. The picker
// stays open behind this surface so dismissing with Esc / outside click /
// Cancel returns keyboard focus to the picker automatically (Quickshell
// re-asserts the picker's Exclusive focus when this Overlay drops).
//
// Consumer of StyledDialog { role: Confirm }. Title and body copy are
// derived from PowerMenu.pendingAction at open time.
StyledDialog {
    id: root

    name: "powermenu-confirm"
    role: 1  // StyledDialog.roleConfirm
    open: PowerMenu.confirmOpen
    maxWidth:  Sizing.px(380)
    maxHeight: Sizing.px(220)
    // User already picked the action in the picker; focus the danger button
    // so Enter completes. Cancel still reachable via Tab / Esc / outside click.
    dangerDefault: true

    // Render on the same monitor as the picker.
    screen: {
        const fm = Hyprland.focusedMonitor
        if (!fm) return null
        const list = Quickshell.screens
        for (let i = 0; i < list.length; i++)
            if (list[i].name === fm.name) return list[i]
        return null
    }

    // Read the ArcheDialog-exposed `dismissReason` property —
    // parameterless signal (see ArcheDialog.qml "HISTORY" comment for why).
    onDismissed: {
        if (root.dismissReason === "action") {
            PowerMenu.confirm()
        } else {
            // Esc / outside / cancel / monitor-left — all just cancel.
            PowerMenu.cancel()
        }
    }

    // ─── Card content ──────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Spacing.dialogContentGap

        // Title: "Shutdown?" / "Reboot?"
        Text {
            Layout.fillWidth: true
            text: (PowerMenu.pendingAction?.label ?? "") + "?"
            color: Colors.fg
            font.family: Typography.fontSans
            font.pixelSize: Typography.fontLabel
            font.weight: Typography.weightDemiBold
            wrapMode: Text.WordWrap
        }

        // Body: session-end warning tailored to the action.
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: {
                const id = PowerMenu.pendingAction?.id ?? ""
                if (id === "shutdown") return "Your session will end and the system will power off."
                if (id === "reboot")   return "Your session will end and the system will restart."
                return ""
            }
            color: Colors.fgMuted
            font.family: Typography.fontSans
            font.pixelSize: Typography.fontBody
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        // Button row: Cancel (neutral) + Danger (outlined critical)
        RowLayout {
            Layout.fillWidth: true
            spacing: Spacing.dialogContentGap

            Item { Layout.fillWidth: true }

            // Cancel button
            Rectangle {
                id: cancelBtn
                Layout.preferredWidth: implicitWidth + Spacing.lg * 2
                Layout.preferredHeight: Sizing.px(36)
                implicitWidth: cancelLabel.implicitWidth
                radius: Shape.radiusSm
                color: "transparent"
                border.color: Colors.border
                border.width: Shape.borderThin

                // Focus ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: parent.radius + 2
                    color: "transparent"
                    border.color: Colors.accent
                    border.width: cancelBtn.activeFocus ? 1 : 0
                    opacity: 0.6
                }

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightMedium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._emitDismissal("cancel")
                }

                activeFocusOnTab: true
                Keys.onReturnPressed: root._emitDismissal("cancel")
                Keys.onEnterPressed: root._emitDismissal("cancel")
                Keys.onEscapePressed: root._emitDismissal("esc")

                // Arrow navigation mirrors Tab order.
                Keys.onLeftPressed: cancelBtn.forceActiveFocus()
                Keys.onRightPressed: dangerBtn.forceActiveFocus()
            }

            // Danger button — outlined in critical, transparent fill at rest
            Rectangle {
                id: dangerBtn
                Layout.preferredWidth: implicitWidth + Spacing.lg * 2
                Layout.preferredHeight: Sizing.px(36)
                implicitWidth: dangerLabel.implicitWidth
                radius: Shape.radiusSm
                color: dangerHover.containsMouse ? Colors.dangerBg : "transparent"
                border.color: Colors.dangerBorder
                border.width: Shape.borderThin

                Behavior on color { CAnim { type: "fast" } }

                // Focus ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: parent.radius + 2
                    color: "transparent"
                    border.color: Colors.critical
                    border.width: dangerBtn.activeFocus ? 1 : 0
                    opacity: 0.5
                }

                Text {
                    id: dangerLabel
                    anchors.centerIn: parent
                    text: PowerMenu.pendingAction?.label ?? "Confirm"
                    color: Colors.critical
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightMedium
                }

                MouseArea {
                    id: dangerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._emitDismissal("action")
                }

                activeFocusOnTab: true
                Keys.onReturnPressed: root._emitDismissal("action")
                Keys.onEnterPressed: root._emitDismissal("action")
                Keys.onEscapePressed: root._emitDismissal("esc")

                Keys.onLeftPressed: cancelBtn.forceActiveFocus()
                Keys.onRightPressed: dangerBtn.forceActiveFocus()
            }
        }
    }

    // Focus initial target when dialog opens.
    // dangerDefault = false (default) → Cancel gets focus (safe default).
    // dangerDefault = true → Danger gets focus (opt-in via caller).
    onOpenChanged: {
        if (open) {
            Qt.callLater(() => {
                if (root.dangerDefault) dangerBtn.forceActiveFocus()
                else                    cancelBtn.forceActiveFocus()
            })
        }
    }
}
