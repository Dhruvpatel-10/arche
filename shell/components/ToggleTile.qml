import QtQuick
import ".."
import "../theme"

// ToggleTile — a square tile with an icon disc, label, subtitle, and an
// active/inactive visual state. Used in the ControlCenter toggle grid.
// When active, both the tile surface and the icon disc flip: tile reads
// brighter (tileBgActive) and the disc fills with `fgOnActive` (pure
// white punctuation) with bgAlt text inside it.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool wide: false
    signal clicked()
    signal rightClicked()

    implicitHeight: Sizing.px(66)
    implicitWidth: wide ? Sizing.px(372) : Sizing.px(180)
    radius: Shape.radiusTile
    color: tileColor
    clip: true

    readonly property color tileColor: active ? Colors.tileBgActive : Colors.tileBg

    StateLayer {
        anchors.fill: parent
        source: mouse
        tint: Colors.fg
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Spacing.md
            rightMargin: Spacing.md
        }
        spacing: Spacing.md

        Rectangle {
            width: Sizing.px(38); height: Sizing.px(38)
            radius: width / 2
            color: root.active ? Colors.fgOnActive : Colors.bgAlt
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? Colors.bgAlt : Colors.fg
                font { family: Typography.fontMono; pixelSize: Typography.fontTitle }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.label
                color: Colors.fg
                font { family: Typography.fontSans; pixelSize: Typography.fontBody; weight: Typography.weightDemiBold }
                elide: Text.ElideRight
            }
            Text {
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Colors.fgMuted
                font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouseEvent => {
            if (mouseEvent.button === Qt.RightButton) root.rightClicked()
            else root.clicked()
        }
    }

    Behavior on color { CAnim { type: "fast" } }
}
