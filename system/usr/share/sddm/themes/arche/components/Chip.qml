import QtQuick 2.15

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property color surfaceColor: "#1d2029"
    property color borderColor: "#282c38"
    property color accentColor: "#c9943e"
    property string fontFamily: "IBM Plex Sans"
    property bool interactive: true
    property bool hovered: false

    signal clicked()

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 24
    radius: height / 2
    color: hovered ? surfaceColor : "transparent"
    border.color: hovered ? accentColor : borderColor
    border.width: 1
    opacity: interactive ? 1.0 : 0.55

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: root.label
            color: root.fgMuted
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: Font.Normal
        }
        Text {
            text: root.value
            color: root.fgColor
            font.family: root.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }
}
