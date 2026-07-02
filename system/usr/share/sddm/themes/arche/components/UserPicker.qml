import QtQuick 2.15

Row {
    id: picker

    property var model: null
    property int selectedIndex: 0
    property color accentColor: "#c9943e"
    property color fgColor: "#cdc8bc"
    property color fgMuted: "#817c72"
    property color fgDim: "#3a3d48"
    property string fontFamily: "MesloLGS Nerd Font Mono"
    property int fontSize: 32

    signal userSelected(int index, string userName)

    spacing: 0

    function userNameAt(idx) {
        var item = rep.itemAt(idx)
        return item ? item.userNameRef : ""
    }

    Repeater {
        id: rep
        model: picker.model

        delegate: Row {
            id: cell
            spacing: 0
            property string userNameRef: model.name
            property int userIndex: index

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: index > 0 ? "  |  " : ""
                color: picker.fgDim
                font.family: picker.fontFamily
                font.pixelSize: picker.fontSize
            }

            Item {
                width: nameText.implicitWidth
                height: nameText.implicitHeight + 8

                Text {
                    id: nameText
                    text: model.name
                    color: index === picker.selectedIndex ? picker.accentColor : picker.fgMuted
                    font.family: picker.fontFamily
                    font.pixelSize: picker.fontSize
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                Rectangle {
                    visible: index === picker.selectedIndex
                    anchors.top: nameText.bottom
                    anchors.topMargin: 2
                    anchors.left: nameText.left
                    width: nameText.implicitWidth
                    height: 2
                    color: picker.accentColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.userSelected(index, model.name)
                }
            }
        }
    }
}
