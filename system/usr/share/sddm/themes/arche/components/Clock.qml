import QtQuick 2.15

Column {
    id: root

    property string fontFamily: "IBM Plex Sans"
    property string monoFamily: "MesloLGS Nerd Font Mono"
    property color textColor: "#cdc8bc"
    property color mutedColor: "#817c72"
    property int hourFormat: 24

    spacing: 4

    function two(n) { return n < 10 ? "0" + n : "" + n }

    function formatTime(d) {
        var h = d.getHours()
        var m = d.getMinutes()
        if (root.hourFormat === 12) {
            var suf = h >= 12 ? " PM" : " AM"
            h = h % 12; if (h === 0) h = 12
            return two(h) + ":" + two(m) + suf
        }
        return two(h) + ":" + two(m)
    }

    function formatDate(d) {
        var days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        var months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
        return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
    }

    Text {
        id: timeText
        text: root.formatTime(new Date())
        color: root.textColor
        font.family: root.monoFamily
        font.pixelSize: 64
        font.weight: Font.Light
        font.letterSpacing: -2
    }

    Text {
        text: root.formatDate(new Date())
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: Font.Normal
        opacity: 0.9
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var d = new Date()
            timeText.text = root.formatTime(d)
        }
    }
}
