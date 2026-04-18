import QtQuick 2.15

Item {
    id: root

    property string userName: ""
    property string realName: ""
    property bool selected: false
    property color accentColor: "#c9943e"
    property color surfaceColor: "#1d2029"
    property color borderColor: "#282c38"
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property string fontFamily: "IBM Plex Sans"
    property int avatarSize: 112

    signal clicked()

    width: avatarSize + 16
    height: avatarSize + 48

    // Accent ring — inflates when selected to give a subtle pop
    Rectangle {
        id: ring
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: avatarSize + (root.selected ? 12 : 0)
        height: width
        radius: width / 2
        color: "transparent"
        border.color: root.selected ? root.accentColor : root.borderColor
        border.width: root.selected ? 2 : 1
        opacity: root.selected ? 1.0 : 0.5

        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // Avatar disc (initial; falls back when no icon). Clean, consistent look.
        Rectangle {
            id: avatarBg
            anchors.centerIn: parent
            width: parent.width - 8
            height: width
            radius: width / 2
            color: root.surfaceColor

            Text {
                anchors.centerIn: parent
                text: {
                    var src = root.realName.length > 0 ? root.realName : root.userName
                    return src.length > 0 ? src.charAt(0).toUpperCase() : "?"
                }
                color: root.selected ? root.accentColor : root.fgMuted
                font.family: root.fontFamily
                font.pixelSize: Math.round(parent.width * 0.42)
                font.weight: Font.Light
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: ring.bottom
        anchors.topMargin: 14
        text: root.realName.length > 0 ? root.realName : root.userName
        color: root.selected ? root.fgColor : root.fgMuted
        font.family: root.fontFamily
        font.pixelSize: 14
        font.weight: root.selected ? Font.Medium : Font.Normal
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        width: root.width + 32
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
        onEntered: if (!root.selected) ring.opacity = 0.85
        onExited: if (!root.selected) ring.opacity = 0.5
    }
}
