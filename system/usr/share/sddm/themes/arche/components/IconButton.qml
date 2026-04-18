import QtQuick 2.15

Rectangle {
    id: root

    property string glyph: ""
    property string tooltip: ""
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property color surfaceColor: "#1d2029"
    property color borderColor: "#282c38"
    property color accentColor: "#c9943e"
    property string fontFamily: "IBM Plex Sans"
    property bool hovered: false

    signal clicked()

    implicitWidth: 40
    implicitHeight: 40
    radius: width / 2
    color: hovered ? surfaceColor : "transparent"
    border.color: hovered ? accentColor : borderColor
    border.width: 1

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        color: root.hovered ? root.fgColor : root.fgMuted
        font.family: root.fontFamily
        font.pixelSize: 16
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }

    Rectangle {
        id: tip
        visible: root.hovered && root.tooltip.length > 0
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tipText.implicitWidth + 14
        height: tipText.implicitHeight + 8
        radius: 6
        color: root.surfaceColor
        border.color: root.borderColor
        border.width: 1
        opacity: 0.95

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltip
            color: root.fgColor
            font.family: root.fontFamily
            font.pixelSize: 11
        }
    }
}
