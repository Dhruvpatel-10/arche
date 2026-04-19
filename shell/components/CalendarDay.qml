import QtQuick
import ".."
import "../theme"

// CalendarDay — one day cell in the calendar grid. Pure view — parent
// supplies the state flags and listens for `clicked`. Sizing is driven
// by the grid's cell pitch (set externally via width/height).
Rectangle {
    id: root

    property int  dayNumber: 0
    property bool inMonth: true
    property bool isToday: false
    property bool isSelected: false

    signal clicked()

    radius: height / 2     // full pill
    opacity: inMonth ? 1.0 : 0.28

    color: root.isToday     ? Theme.accent
         : mouse.containsMouse && root.inMonth ? Theme.tileBg
         : "transparent"

    border.color: root.isSelected && !root.isToday ? Theme.accent : "transparent"
    border.width: root.isSelected && !root.isToday ? Theme.borderThin ?? 1 : 0

    Text {
        anchors.centerIn: parent
        text: root.dayNumber
        color: root.isToday    ? Theme.bgAlt
             : root.isSelected ? Theme.accent
             : Theme.fg
        font {
            family:    Theme.fontSans
            pixelSize: Theme.fontBody
            weight:    (root.isToday || root.isSelected) ? Font.DemiBold : Font.Normal
            features:  { "tnum": 1 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.inMonth) root.clicked()
    }

    Behavior on color        { ColorAnimation  { duration: Motion.durationFast } }
    Behavior on border.color { ColorAnimation  { duration: Motion.durationFast } }
    Behavior on opacity      { NumberAnimation { duration: Motion.durationFast } }
}
