import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property int iconSize: 14
    property color iconColor: Theme.fg
    signal clicked()

    width: 32
    height: 32
    radius: 16
    color: Theme.tileBg
    clip: true

    StateLayer {
        anchors.fill: parent
        source: mouseArea
        tint: Theme.fg
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        font { family: Theme.fontMono; pixelSize: root.iconSize }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
