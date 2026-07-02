import QtQuick 2.15

Column {
    id: root

    property string fontFamily: "MesloLGS Nerd Font Mono"
    property color textColor: "#cdc8bc"
    property color mutedColor: "#817c72"
    property int hourFormat: 24
    property bool showSeconds: true

    spacing: 4

    function two(n) { return n < 10 ? "0" + n : "" + n }

    function formatTime(d) {
        var h = d.getHours()
        var m = d.getMinutes()
        var s = d.getSeconds()
        if (root.hourFormat === 12) {
            var suf = h >= 12 ? " PM" : " AM"
            h = h % 12; if (h === 0) h = 12
            return two(h) + ":" + two(m) + (root.showSeconds ? ":" + two(s) : "") + suf
        }
        return two(h) + ":" + two(m) + (root.showSeconds ? ":" + two(s) : "")
    }

    function formatDate(d) {
        var days = ["sun","mon","tue","wed","thu","fri","sat"]
        return d.getFullYear() + "-" + two(d.getMonth() + 1) + "-" + two(d.getDate()) + " " + days[d.getDay()]
    }

    // Children sized intrinsically so Column.implicitWidth is non-zero;
    // right-alignment is handled by the parent's anchor in Main.qml.
    Text {
        id: timeText
        anchors.right: parent.right
        text: root.formatTime(new Date())
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 48
        font.weight: Font.Light
        font.letterSpacing: 1
    }

    Text {
        id: dateText
        width: timeText.width
        horizontalAlignment: Text.AlignRight
        text: root.formatDate(new Date())
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: 12
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            timeText.text = root.formatTime(d)
            dateText.text = root.formatDate(d)
        }
    }
}
