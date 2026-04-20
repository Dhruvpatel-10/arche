import QtQuick
import "../theme"

// IconButton — circular button with a glyph and the standard hover/press
// state layer. Used wherever the shell needs a tappable icon: media
// transport, powermenu header, notification dismiss, popover close.
//
// Keep this a primitive — no tooltips, no ripples. Composition (size,
// color, glyph) is the caller's job.
Rectangle {
    id: root
    property string icon: ""
    property int iconSize: Sizing.fpx(14)
    property color iconColor: Colors.fg
    signal clicked()

    width: Sizing.px(32)
    height: Sizing.px(32)
    radius: width / 2
    color: Colors.tileBg
    clip: true

    StateLayer {
        anchors.fill: parent
        source: mouseArea
        tint: Colors.fg
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font { family: Typography.fontMono; pixelSize: root.iconSize }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
