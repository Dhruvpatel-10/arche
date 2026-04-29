import QtQuick
import QtQuick.Layouts
import "../../theme"

// DialogHeader — standard dialog / popover header row.
//
// One icon, one title, optional subtitle, optional right-aligned trailing
// slot (for Clear All, a mode toggle, etc.). Paired with DialogSection
// and DialogDivider it gives every popover the same skeleton:
//
//   DialogHeader { icon: "\uf0f3"; title: "Notifications" }
//   DialogDivider {}
//   DialogSection { label: "..." ; content ... }
//
// Why a separate component instead of inlining the Row: the existing
// popovers each rebuild this header slightly differently (spacing, icon
// size, title weight), which drifted. Centralizing the spec here fixes
// the drift and means a later polish touches one file.
RowLayout {
    id: root

    property string icon:     ""
    property color  iconColor: Colors.accent
    property string title:    ""
    property string subtitle: ""

    // Optional trailing Component (e.g. a button). Rendered right-aligned.
    property Component trailingComponent: null

    Layout.fillWidth: true
    spacing: Spacing.sm

    Text {
        Layout.alignment: Qt.AlignVCenter
        visible: root.icon.length > 0
        text: root.icon
        color: root.iconColor
        font.family: Typography.fontMono
        font.pixelSize: Typography.fontLabel
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: Sizing.px(1)

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Colors.fg
            font.family: Typography.fontSans
            font.pixelSize: Typography.fontBody
            font.weight: Typography.weightDemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Colors.fgMuted
            font.family: Typography.fontSans
            font.pixelSize: Typography.fontMicro
            elide: Text.ElideRight
        }
    }

    Loader {
        Layout.alignment: Qt.AlignVCenter
        active:  root.trailingComponent !== null
        visible: active
        sourceComponent: root.trailingComponent
    }
}
