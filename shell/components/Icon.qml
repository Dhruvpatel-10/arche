import QtQuick
import ".."

Text {
    property int size: Theme.fontSize + 2
    font.family: Theme.fontMono
    font.pixelSize: size
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
