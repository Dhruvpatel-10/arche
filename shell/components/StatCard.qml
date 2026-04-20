import QtQuick
import "../theme"

// StatCard — compact metric tile (CPU / RAM / Disk) for the control
// center grid. Icon + big percent number up top, a thin horizontal bar
// below, uppercase label at the bottom.
//
// Theme tokens: all colors, typography, spacing and shape come from
// theme/*. No raw hex, pixel sizes, or font stacks.
Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property int percent: 0

    implicitHeight: Sizing.px(64)
    color: Colors.tileBg
    radius: Shape.radiusTile

    Column {
        anchors {
            fill: parent
            topMargin: Spacing.md
            leftMargin: Spacing.md
            rightMargin: Spacing.md
            bottomMargin: Spacing.md
        }
        spacing: Spacing.xs - 1   // 3 px — gap between icon row and the bar

        Row {
            spacing: Spacing.sm
            Text {
                text: root.icon
                color: Colors.fgMuted
                font { family: Typography.fontMono; pixelSize: Typography.fontCaption }
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.percent + "%"
                color: Colors.fg
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontTitle
                    weight: Font.DemiBold
                    features: { "tnum": 1 }
                }
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Progress bar. Behavior uses the `med` Anim preset so the fill
        // eases in a bit slower than the text flip — reads as a smooth
        // trend, not a jitter.
        Rectangle {
            width: parent.width
            height: Sizing.px(3)
            radius: height / 2
            color: Colors.bgAlt
            Rectangle {
                width: parent.width * root.percent / 100
                height: parent.height
                radius: parent.radius
                color: Colors.accent
                Behavior on width { Anim { type: "med" } }
            }
        }

        Item { width: 1; height: Sizing.px(2) }

        Text {
            text: root.label
            color: Colors.fgDim
            font {
                family: Typography.fontSans
                pixelSize: Typography.fontCaption
                letterSpacing: 0.6
                capitalization: Font.AllUppercase
                weight: Font.Medium
            }
        }
    }
}
