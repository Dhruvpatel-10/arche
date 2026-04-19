import QtQuick
import QtQuick.Layouts
import "../.."

// PowerMenuItem — single row in the power menu list. Glyph + label.
// The base picker's ListView assigns ListView.isCurrentItem — bind
// `selected` from that on the consumer side to get the accent tint.
Rectangle {
    id: root

    required property var  action
    required property bool selected

    signal activated()

    implicitHeight: 48
    radius: 8
    color: selected
        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.11)
        : "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin:  14
            rightMargin: 14
        }
        spacing: 14

        Text {
            Layout.alignment: Qt.AlignVCenter
            text:  root.action.icon
            color: root.selected ? Theme.accent : Theme.fgMuted
            font {
                family:    Theme.fontMono
                pixelSize: Theme.fontLabel
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text:  root.action.label
            color: Theme.fg
            font {
                family:    Theme.fontSans
                pixelSize: Theme.fontBody
            }
        }
    }
}
