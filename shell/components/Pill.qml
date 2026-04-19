import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    default property alias content: row.data
    property int padding: Theme.pad
    property int spacing: 8
    signal clicked()
    signal scrolled(int delta)

    color: Theme.pillBg
    radius: Theme.radiusPill
    height: 28
    implicitWidth: row.implicitWidth + padding * 2
    clip: true

    StateLayer {
        anchors.fill: parent
        source: mouseArea
        tint: Theme.fg
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
