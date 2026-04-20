import QtQuick
import Quickshell.Services.Notifications
import ".."
import "../theme"

// Toast — live notification popup. Renders in the top-right of the focused
// screen via ToastLayer. Click body to trigger the default action (e.g.
// open satty on Screenshot notifications); Meta-click or X-button to
// dismiss without invoking.
//
// Motion: two independent Behaviors — one on opacity, one on the Translate
// leaf `slide.x`. `Behavior on transform` is a no-op because `transform`
// is a list property and Behaviors don't fire on list mutations. See
// pitfalls trap #1.
Rectangle {
    id: root
    required property Notification notification

    function defaultAction() {
        const appName = notification.appName
        const appIcon = notification.appIcon
        const body = notification.body
        notification.dismiss()
        Notifs.invokeDefault(appName, appIcon, body)
    }

    implicitHeight: Math.max(Sizing.px(58), col.implicitHeight + Spacing.lg)
    color: Colors.card
    radius: Shape.radiusTile
    border.color: Colors.border
    border.width: Shape.borderThin

    opacity: 0
    // Enter-from-right distance — slightly wider than `Spacing.xl` so the
    // toast reads as sliding in from off-canvas rather than from its own
    // right margin. Paired with the opacity fade in Component.onCompleted
    // below so each toast both translates and fades in via one trigger.
    transform: Translate { id: slide; x: Sizing.px(40) }

    Component.onCompleted: {
        opacity = 1
        slide.x = 0
    }

    Behavior on opacity { Anim { type: "standard" } }
    Behavior on slide.x { Anim { type: "standard" } }

    Row {
        anchors {
            fill: parent
            leftMargin: Spacing.md
            rightMargin: Spacing.md
        }
        spacing: Spacing.md

        // Icon disc. If the notification carries a path-like appIcon,
        // prefer that; otherwise fall back to a bell glyph tinted to the
        // accent so the toast still reads as an arrival, not a silent card.
        Rectangle {
            id: iconDisc
            width: Sizing.px(36)
            height: Sizing.px(36)
            radius: width / 2
            color: Colors.accent
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool hasImage:
                typeof root.notification.appIcon === "string"
                && root.notification.appIcon.startsWith("/")

            Image {
                anchors.fill: parent
                anchors.margins: Sizing.px(4)
                source: iconDisc.hasImage ? root.notification.appIcon : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: iconDisc.hasImage && status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                text: "\uf0f3"
                color: Colors.bgAlt
                font { family: Typography.fontMono; pixelSize: Typography.fontLabel }
                visible: !iconDisc.hasImage
            }
        }

        Column {
            id: col
            width: parent.width - iconDisc.width - Spacing.md
                   - Sizing.px(24) - Spacing.md
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: root.notification.summary
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
                visible: text.length > 0
                text: root.notification.body
                color: Colors.fgMuted
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.notification.appName
                color: Colors.fgDim
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                width: parent.width
                elide: Text.ElideRight
            }
        }

        IconButton {
            width: Sizing.px(24)
            height: Sizing.px(24)
            radius: width / 2
            color: "transparent"
            icon: "\uf00d"
            iconSize: Sizing.fpx(9)
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.notification.dismiss()
        }
    }

    MouseArea {
        anchors.fill: parent
        // Exclude the X button region so clicks on X don't also trigger
        // the default action (e.g. accidentally launching satty on dismiss).
        anchors.rightMargin: Sizing.px(36)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.modifiers & Qt.MetaModifier) {
                root.notification.dismiss()
            } else {
                root.defaultAction()
            }
        }
    }
}
