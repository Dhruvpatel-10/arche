import QtQuick
import Quickshell.Services.Mpris
import ".."

Rectangle {
    id: root
    readonly property MprisPlayer player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    implicitHeight: 72
    color: Theme.bgAlt
    radius: Theme.radiusTile
    visible: player !== null

    Row {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 12

        Image {
            width: 52; height: 52
            anchors.verticalCenter: parent.verticalCenter
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            smooth: true
            asynchronous: true
            Rectangle {
                visible: parent.status !== Image.Ready
                anchors.fill: parent
                color: Theme.tileBg
                radius: 6
            }
            layer.enabled: true
        }

        Column {
            width: parent.width - 52 - 12 - 108 - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: root.player?.trackTitle ?? "Nothing playing"
                color: Theme.fg
                font { family: Theme.fontSans; pixelSize: Theme.fontSize; weight: Font.DemiBold }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.player?.trackArtist ?? ""
                color: Theme.fgMuted
                font { family: Theme.fontSans; pixelSize: Theme.fontSizeSmall }
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Row {
            width: 108
            height: 40   // match the largest child so verticalCenter has room
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf048"; iconSize: 11
                onClicked: root.player?.previous()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: Theme.fg
                iconColor: Theme.bgAlt
                icon: root.player?.isPlaying ? "\uf04c" : "\uf04b"
                iconSize: 14
                onClicked: root.player?.togglePlaying()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf051"; iconSize: 11
                onClicked: root.player?.next()
            }
        }
    }
}
