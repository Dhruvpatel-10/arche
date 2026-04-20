import QtQuick
import QtQuick.Layouts
import "../theme"

// WingPill — small rounded-rect pill for the split-notch right wing.
// Height 24, radius Shape.radiusPillWing (9px scaled), dedicated
// pillBg / pillBgHover color roles so drawer polish doesn't drag the
// bar's hover along with it.
Rectangle {
    id: root
    default property alias content: row.data
    property int spacing: Spacing.sm
    property int padding: Spacing.md

    // Set to true/false to paint the bottom-right status dot. null =
    // no status dot. Used by Wi-Fi / Bluetooth pills.
    property var statusOn: null

    signal clicked()
    signal scrolled(int delta)

    Layout.preferredHeight: Sizing.px(24)
    implicitHeight: Sizing.px(24)
    implicitWidth: row.implicitWidth + padding * 2
    radius: Shape.radiusPillWing
    color: mouseArea.containsMouse ? Colors.pillBgHover : Colors.pillBg
    border.color: Colors.border
    border.width: Shape.borderThin

    Behavior on color { CAnim { type: "fast" } }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        spacing: root.spacing
    }

    // Status indicator dot — bottom-right, tiny. Only rendered when the
    // caller passes a non-null statusOn value.
    Rectangle {
        visible: root.statusOn !== null
        anchors.right: parent.right
        anchors.rightMargin: Sizing.px(5)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Sizing.px(2)
        width: Sizing.px(3); height: Sizing.px(3)
        radius: width / 2
        color: root.statusOn ? Colors.success : Colors.fgDim
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: event => {
            root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
            event.accepted = true
        }
    }
}
