import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property string subtitle: ""
    property bool active: false
    property bool wide: false
    signal clicked()

    implicitHeight: 66
    implicitWidth: wide ? 372 : 180
    radius: Theme.radiusTile
    color: tileColor
    clip: true

    readonly property color tileColor: active ? "#2a2d38" : Theme.tileBg

    StateLayer {
        anchors.fill: parent
        source: mouse
        tint: Theme.fg
    }

    Row {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 10

        Rectangle {
            width: 38; height: 38; radius: 19
            color: active ? "#ffffff" : Theme.bgAlt
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: active ? Theme.bgAlt : Theme.fg
                font { family: Theme.fontMono; pixelSize: Theme.fontTitle }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: root.label
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontBody; weight: Font.DemiBold }
                elide: Text.ElideRight
            }
            Text {
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontCaption }
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Behavior on color { ColorAnimation { duration: 120 } }
}
