import QtQuick
import QtQuick.Layouts
import "../theme"

// WingPill — small rounded-rect tap target for the right-wing clusters.
//
// Redesign 2026-04-20: unboxed look. No border at rest, no fill at rest.
// Hover reveals a subtle surface wash; the icon(s)/numeral(s) are the
// shape at rest. This lets three pills in a row read as *one cluster*
// instead of three chips against the bar surface.
//
// Height is Sizing.pxFor(22, …) — one rhythm for every right-wing cluster
// (see BarStatusPills.qml for the vertical contract). Corners are slightly
// rounded (Shape.radiusPillWing) so the hover wash doesn't hard-clip.
Rectangle {
    id: root
    default property alias content: row.data
    property int spacing: Spacing.sm
    property int padding: Spacing.smMd
    // Height lives on the parent; lets BarStatusPills use the same rhythm
    // across all pills even when one has no visible hover.
    property int pillHeight: Sizing.px(22)

    // Set to true/false to paint the bottom-right status dot. null =
    // no status dot. Used by Wi-Fi / Bluetooth pills.
    property var statusOn: null

    signal clicked()
    signal scrolled(int delta)

    Layout.preferredHeight: pillHeight
    implicitHeight: pillHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: Shape.radiusPillWing
    // Transparent at rest — no chip silhouette. Hover only.
    color: mouseArea.containsMouse ? Colors.pillBgHover : "transparent"
    border.width: 0

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
