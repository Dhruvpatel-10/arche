import QtQuick
import QtQuick.Controls
import "../theme"

// SliderRow — icon + horizontal slider + percent readout. Scroll over the
// slider to step the value; right-click forwards `rightClicked()` so the
// caller can open a companion tool (wiremix, etc.).
Item {
    id: root
    property string icon: ""
    property real value: 0
    property int percent: Math.round(value * 100)
    property real scrollStep: 0.05
    signal moved(real v)
    signal rightClicked()

    implicitHeight: Sizing.px(36)

    Row {
        anchors.fill: parent
        spacing: Spacing.md

        Rectangle {
            width: Sizing.px(28)
            height: Sizing.px(28)
            radius: width / 2
            color: "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent
                text: root.icon
                color: Colors.fg
                font { family: Typography.fontMono; pixelSize: Typography.fontTitle }
            }
        }

        Slider {
            id: slider
            width: parent.width - Sizing.px(28) - Sizing.px(48) - Spacing.md * 2
            height: Sizing.px(28)
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 1
            value: root.value
            onMoved: root.moved(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: Sizing.px(18)
                radius: height / 2
                color: Colors.bgAlt
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: Colors.fg
                }
            }
            handle: Item {}

            // Wheel scrolls the value. Intentionally does NOT write
            // `slider.value` imperatively — that would break the
            // `value: root.value` binding and the thumb would stop
            // following external mutations (OSD, wiremix, volume keys).
            // We only emit `root.moved(next)`; the parent updates
            // `root.value`, which re-flows through the binding.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = event.angleDelta.y > 0 ? root.scrollStep : -root.scrollStep
                    const next = Math.max(0, Math.min(1, slider.value + delta))
                    root.moved(next)
                }
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: root.rightClicked()
            }
        }

        Text {
            width: Sizing.px(48)
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "%"
            color: Colors.fg
            font {
                family: Typography.fontSans
                pixelSize: Typography.fontBody
                weight: Font.Medium
            }
            horizontalAlignment: Text.AlignRight
        }
    }
}
