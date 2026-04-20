import QtQuick
import QtQuick.Layouts
import "../theme"

// Pill — small rounded container with a state layer for hover/press.
// Used in the bar for status glyphs (wifi / bt / battery), in the
// notifications list for the "Clear All" chip, and anywhere the shell
// wants a compact interactive badge.
//
// `content` is a default alias onto an inner RowLayout — callers just
// drop children and the layout arranges them horizontally.
Rectangle {
    id: root
    default property alias content: row.data
    property int padding: Spacing.md
    property int spacing: Spacing.smMd   // default gap between pill items
    signal clicked()
    signal scrolled(int delta)

    color: Colors.pillBg
    radius: Shape.radiusPill
    height: Sizing.px(28)
    implicitWidth: row.implicitWidth + padding * 2
    clip: true

    StateLayer {
        anchors.fill: parent
        source: mouseArea
        tint: Colors.fg
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: event => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
            event.accepted = true
        }
    }
}
