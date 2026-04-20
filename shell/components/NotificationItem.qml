import QtQuick
import ".."
import "../theme"

// NotificationItem — single row in the notifications list. Icon disc on
// the left, summary / body / meta in the middle, dismiss X on the right.
// Click body to trigger the default action; Meta-click to dismiss without
// invoking the app.
//
// Motion uses the shared Anim / CAnim presets so hover recolor and
// dismiss-fade match the rest of the shell — no bespoke durations.
Rectangle {
    id: root
    required property var entry

    function relativeTime(ms) {
        const diff = Math.max(0, Date.now() - ms)
        const m = Math.floor(diff / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + "m ago"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h ago"
        return Math.floor(h / 24) + "d ago"
    }

    function defaultAction() {
        // Remove first so the UI updates instantly; satty's cold start then
        // happens in the background without the panel feeling stuck.
        const appName = entry.appName
        const appIcon = entry.appIcon
        const body = entry.body
        Notifs.removeFromHistory(entry)
        Notifs.invokeDefault(appName, appIcon, body)
    }

    implicitHeight: Sizing.px(58)
    color: hoverArea.containsMouse ? Colors.tileBgActive : Colors.tileBg
    radius: Shape.radiusTile
    opacity: entry.dismissed ? Effects.opacityMuted : 1.0

    Behavior on opacity { Anim  { type: "fast" } }
    Behavior on color   { CAnim { type: "fast" } }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        // Exclude the X button region so clicks on X don't bleed into
        // the body's default-action handler. Matches the right-side
        // layout below: dismiss button (24) + Row rightMargin (12) = 36.
        anchors.rightMargin: Sizing.px(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.modifiers & Qt.MetaModifier) {
                Notifs.removeFromHistory(root.entry)
            } else {
                root.defaultAction()
            }
        }
    }

    Row {
        anchors {
            fill: parent
            leftMargin: Spacing.md
            rightMargin: Spacing.md
        }
        spacing: Spacing.md

        Rectangle {
            width: Sizing.px(36)
            height: Sizing.px(36)
            radius: width / 2
            color: Colors.bgAlt
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: "\uf0f3"
                color: Colors.fg
                font { family: Typography.fontMono; pixelSize: Typography.fontLabel }
            }
        }

        Column {
            width: parent.width - Sizing.px(36) - Spacing.md
                   - Sizing.px(24) - Spacing.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.entry.summary
                color: Colors.fg
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontBody
                    weight: Font.DemiBold
                }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.entry.body
                color: Colors.fgMuted
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                elide: Text.ElideRight
                width: parent.width
                visible: text.length > 0
            }
            Text {
                text: (root.entry.appName || "")
                      + (root.entry.appName ? " · " : "")
                      + root.relativeTime(root.entry.time)
                color: Colors.fgDim
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                elide: Text.ElideRight
                width: parent.width
            }
        }

        IconButton {
            width: Sizing.px(24)
            height: Sizing.px(24)
            radius: width / 2
            icon: "\uf00d"
            iconSize: Sizing.fpx(9)
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Notifs.removeFromHistory(root.entry)
        }
    }
}
