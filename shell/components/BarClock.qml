import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../services"
import "../theme"

// BarClock — macOS-style minimal time + date, centered in the bar.
// Transparent at rest, subtle hover wash on mouse-over (matches WingPill's
// unboxed idiom — no at-rest chip silhouette). Click toggles the calendar
// panel; Esc / click-outside dismiss it via CalendarPanel.
//
// Clock source is a minute-precision SystemClock — fewer wake-ups than a
// 1s Timer would cause, and the bar clock never shows seconds anyway.
//
// Adaptive foreground: fgPrimary/fgMuted flip to the dark-on-light
// palette when the wallpaper is light AND the bar is translucent. Under
// fullscreen the opaque surface wins and we keep the warm-white tokens.
Rectangle {
    id: root

    // ─── Inputs ───────────────────────────────────────────────────────
    property string screenName: ""
    property bool hasFullscreen: false

    // ─── Adaptive foreground selector ─────────────────────────────────
    readonly property bool _useLight: !hasFullscreen && WallpaperContrast.isLight
    readonly property color fgPrimary: _useLight ? Colors.fgOnLight : Colors.fg
    readonly property color fgMuted:   _useLight ? Colors.fgMutedOnLight : Colors.fgMuted

    // ─── Unboxed pill ─────────────────────────────────────────────────
    // Transparent at rest, hover wash only.
    color: _hover.containsMouse ? Colors.pillBgHover : "transparent"
    radius: Shape.radiusPillWing
    Behavior on color { CAnim { type: "fast" } }

    implicitWidth: row.implicitWidth + Spacing.md * 2
    implicitHeight: Sizing.barHeightFor(screenName)

    // Clock source — minute precision avoids the per-second wake-ups a
    // full Timer would cost.
    SystemClock {
        id: clockTick
        precision: SystemClock.Minutes
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Spacing.sm

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: Qt.formatDateTime(clockTick.date, "HH:mm")
            color: root.fgPrimary
            font.family: Typography.fontMono
            font.pixelSize: Sizing.fpxFor(12, root.screenName)
            font.weight: Typography.weightDemiBold
            // Tabular digits — keeps "09:59" → "10:00" from jittering.
            font.features: ({ "tnum": 1 })
            // Subtle letterspacing reads as "time", not "number", at
            // mono 12px.
            font.letterSpacing: 0.4
            Behavior on color { CAnim { type: "standard" } }
        }

        // Amber separator dot — tiny Ember brand mark without a glyph.
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Sizing.pxFor(3, root.screenName)
            Layout.preferredHeight: Sizing.pxFor(3, root.screenName)
            radius: width / 2
            color: Colors.accent
            opacity: 0.75
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            // "Mon  Apr 20" — mono-spaced day + month + day numeric.
            text: Qt.formatDateTime(clockTick.date, "ddd  MMM d")
            color: root.fgMuted
            font.family: Typography.fontMono
            font.pixelSize: Sizing.fpxFor(10, root.screenName)
            font.weight: Typography.weightMedium
            Behavior on color { CAnim { type: "standard" } }
        }
    }

    // Click-only — dismissal is owned by CalendarPanel (click-outside /
    // Esc / monitor-change), mirroring every other panel overlay.
    MouseArea {
        id: _hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.calendarOpen = !Ui.calendarOpen
    }
}
