import QtQuick 2.15

Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property color accentColor: "#c9943e"
    property color surfaceColor: "#1d2029"
    property color borderColor: "#282c38"
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property string fontFamily: "IBM Plex Sans"
    property string placeholder: "Password"
    property bool busy: false

    signal submitted()

    implicitWidth: 360
    implicitHeight: 48
    color: surfaceColor
    border.color: input.activeFocus ? accentColor : borderColor
    border.width: input.activeFocus ? 2 : 1

    Behavior on border.color { ColorAnimation { duration: 160 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 6
        spacing: 10

        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - submitBtn.width - parent.spacing
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: fgColor
            selectionColor: accentColor
            selectedTextColor: "#13151c"
            echoMode: TextInput.Password
            passwordCharacter: "•"
            font.family: fontFamily
            font.pixelSize: 15
            focus: true
            Keys.onReturnPressed: root.submitted()
            Keys.onEnterPressed: root.submitted()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: fgMuted
                font: input.font
                visible: input.text.length === 0 && !input.activeFocus
                opacity: 0.7
            }
        }

        Rectangle {
            id: submitBtn
            anchors.verticalCenter: parent.verticalCenter
            width: 36
            height: 36
            radius: width / 2
            color: input.text.length > 0 ? accentColor : "transparent"
            border.color: input.text.length > 0 ? accentColor : borderColor
            border.width: 1
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: root.busy ? "…" : "→"
                color: input.text.length > 0 ? "#13151c" : fgMuted
                font.family: fontFamily
                font.pixelSize: 18
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: input.text.length > 0
                onClicked: root.submitted()
            }
        }
    }

    function forceFocus() { input.forceActiveFocus() }
    function clearPassword() { input.text = "" }
}
