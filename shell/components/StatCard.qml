import QtQuick
import ".."

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property int percent: 0

    implicitHeight: 64
    color: Theme.tileBg
    radius: Theme.radiusTile

    Column {
        anchors {
            fill: parent
            topMargin: 10
            leftMargin: 12
            rightMargin: 12
            bottomMargin: 10
        }
        spacing: 3

        Row {
            spacing: 6
            Text {
                text: root.icon
                color: Theme.fgMuted
                font { family: Theme.fontMono; pixelSize: Theme.fontCaption }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.percent + "%"
                color: Theme.fg
                font {
                    family: Theme.fontSans
                    pixelSize: Theme.fontTitle
                    weight: Font.DemiBold
                    features: { "tnum": 1 }
                }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width
            height: 3
            radius: 1.5
            color: Theme.bgAlt
            Rectangle {
                width: parent.width * root.percent / 100
                height: parent.height
                radius: parent.radius
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }

        Item { width: 1; height: 2 }

        Text {
            text: root.label
            color: Theme.fgDim
            font {
                family: Theme.fontSans
                pixelSize: Theme.fontCaption
                letterSpacing: 0.6
                capitalization: Font.AllUppercase
                weight: Font.Medium
            }
        }
    }
}
