import QtQuick 2.15

Item {
    id: root

    property string glyph: ""
    property string label: ""
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property color accentColor: "#c9943e"
    property string fontFamily: "IBM Plex Sans"
    property string monoFamily: "MesloLGS Nerd Font Mono"
    property bool hovered: false

    signal clicked()

    implicitWidth: Math.max(glyphText.implicitWidth, labelText.implicitWidth) + 12
    implicitHeight: glyphText.implicitHeight + labelText.implicitHeight + 10

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: glyphText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            color: root.hovered ? root.fgColor : root.fgMuted
            font.family: root.fontFamily
            font.pixelSize: 20
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: root.hovered ? root.fgColor : root.fgMuted
            font.family: root.monoFamily
            font.pixelSize: 9
            font.letterSpacing: 1.2
            Behavior on color { ColorAnimation { duration: 140 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }
}
