import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../picker"

// LauncherItem — one app row: themed icon + name / comment. Row chrome
// lives in PickerItemBase.
//
// Icon loading is lazy + bounded: `sourceSize` caps decode dimensions
// so a 512×512 SVG from the Papirus theme pays memory for a 32×32
// raster, not the source. Image is async so scrolling the list never
// stalls on file I/O.
//
// Source resolution handles three cases: absolute path, theme name,
// unset. `iconPath(name, true)` returns "" when the icon doesn't
// resolve to a real file — paired with `visible: status === Ready`
// the Image stays invisible on miss, letting the fallback glyph show
// cleanly instead of Qt's magenta-checker "broken image" placeholder.
PickerItemBase {
    id: root

    required property var app

    rowHeight: 52

    function _iconSource(name) {
        if (!name) return ""
        if (name.charAt(0) === "/") return "file://" + name
        return Quickshell.iconPath(name, true)
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin:  12
            rightMargin: 14
        }
        spacing: 14

        // Icon slot: package-glyph fallback underneath an Image. Image
        // paints over the glyph once ready; status !== Ready reveals it.
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth:  32
            Layout.preferredHeight: 32

            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment:   Text.AlignVCenter
                visible: iconImg.status !== Image.Ready
                text:  "󰏗"              // nf-md-package
                color: root.selected ? Theme.accent : Theme.fgMuted
                font {
                    family:    Theme.fontMono
                    pixelSize: Theme.fontTitle
                }
            }

            Image {
                id: iconImg
                anchors.fill: parent
                sourceSize.width:  32
                sourceSize.height: 32
                source:       root._iconSource(root.app.icon)
                fillMode:     Image.PreserveAspectFit
                smooth:       true
                asynchronous: true
                visible:      status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                elide: LayoutMirroring.enabled ? Text.ElideLeft : Text.ElideRight
                text:  root.app.name
                color: Theme.fg
                font {
                    family:    Theme.fontSans
                    pixelSize: Theme.fontBody
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.app.comment.length > 0
                elide: LayoutMirroring.enabled ? Text.ElideLeft : Text.ElideRight
                text:  root.app.comment
                color: Theme.fgDim
                font {
                    family:    Theme.fontSans
                    pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
