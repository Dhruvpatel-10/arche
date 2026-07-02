import QtQuick 2.15

Item {
    id: root

    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property color accentColor: "#c9943e"
    property color errorColor: "#c45c5c"
    property string fontFamily: "MesloLGS Nerd Font Mono"
    property int fontSize: 18
    property string promptUser: "user"
    property string promptHost: "arche"
    property bool busy: false

    property alias text: input.text

    signal submitted()
    signal previousUser()
    signal nextUser()

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(prefix.implicitHeight, cursor.height) + 4

    Row {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            id: prefix
            text: root.promptUser + "@" + root.promptHost + ":~$ "
            color: root.fgMuted
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
        }

        Text {
            id: dots
            text: {
                var n = Math.min(input.text.length, 32)
                var s = ""
                for (var i = 0; i < n; i++) s += "•"
                return s
            }
            color: root.fgColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
        }

        Item {
            width: 4
            height: root.fontSize
        }

        Rectangle {
            id: cursor
            anchors.verticalCenter: parent.verticalCenter
            width: root.fontSize * 0.55
            height: root.fontSize * 1.05
            color: root.accentColor
            opacity: blink.tick ? 1.0 : 0.0

            Timer {
                id: blink
                interval: 530
                running: true
                repeat: true
                property bool tick: true
                onTriggered: tick = !tick
            }
        }
    }

    TextInput {
        id: input
        opacity: 0
        width: 1
        height: 1
        focus: true
        echoMode: TextInput.Password
        cursorVisible: false
        Keys.onReturnPressed: root.submitted()
        Keys.onEnterPressed: root.submitted()
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Up) {
                root.previousUser(); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                root.nextUser(); event.accepted = true
            } else if (event.key === Qt.Key_Left && input.text.length === 0) {
                root.previousUser(); event.accepted = true
            } else if (event.key === Qt.Key_Right && input.text.length === 0) {
                root.nextUser(); event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                input.text = ""; event.accepted = true
            }
        }
    }

    function forceFocus() { input.forceActiveFocus() }
    function clearPassword() { input.text = "" }
}
