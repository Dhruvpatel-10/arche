import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import ".."
import "../theme"

// AudioMixerPopover — focused popover for the volume pill. Master output
// + microphone + per-app stream sliders, plus an "Open wiremix" escape
// hatch mirroring the right-click on ControlCenter's volume slider.
//
// Per-app discovery: iterate Pipewire.nodes; a stream with .audio is an
// application stream (node.isStream && node.audio). This matches the
// Caelestia services/Audio.qml pattern.
WingPopover {
    id: root
    popoverId: "audio"
    name:      "popover-audio"

    cardWidth:         Sizing.px(360)
    anchorRightMargin: Sizing.px(90)   // roughly under the volume pill
    bodyHeight:        Sizing.px(340)

    // Sticky header — rendered outside the Flickable by WingPopover.
    title:          "Audio"
    titleIcon:      ""
    titleIconColor: Colors.accent

    // ─── Derived lists — rebuilt when Pipewire.nodes changes ─────────
    property var sinkStreams: []
    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root._rebuildStreams() }
    }
    Component.onCompleted: root._rebuildStreams()
    function _rebuildStreams(): void {
        const list = []
        for (const n of (Pipewire.nodes?.values ?? [])) {
            if (n.isStream && n.audio && n.isSink) list.push(n)
        }
        root.sinkStreams = list
    }

    // Keep referenced nodes alive so their audio properties stay bound.
    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSink,
            Pipewire.defaultAudioSource,
            ...root.sinkStreams,
        ]
    }

    contentComponent: Component {
        Column {
            id: body
            width: parent.width
            spacing: Spacing.md

            // ─── Master output ─────────────────────────────────────
            Column {
                width: parent.width
                spacing: Spacing.xs
                Text {
                    text: (Pipewire.defaultAudioSink?.description
                           ?? Pipewire.defaultAudioSink?.name
                           ?? "Output")
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    elide: Text.ElideRight
                    width: parent.width
                }
                SliderRow {
                    width: parent.width
                    icon: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                          ? "" : ""
                    value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                    onMoved: v => {
                        const s = Pipewire.defaultAudioSink?.audio
                        if (!s) return
                        s.muted = false
                        s.volume = v
                    }
                    onRightClicked: {
                        const s = Pipewire.defaultAudioSink?.audio
                        if (s) s.muted = !s.muted
                    }
                }
            }

            // ─── Microphone input ──────────────────────────────────
            Column {
                width: parent.width
                spacing: Spacing.xs
                visible: !!Pipewire.defaultAudioSource
                Text {
                    text: (Pipewire.defaultAudioSource?.description
                           ?? Pipewire.defaultAudioSource?.name
                           ?? "Microphone")
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontMicro
                    elide: Text.ElideRight
                    width: parent.width
                }
                SliderRow {
                    width: parent.width
                    icon: (Pipewire.defaultAudioSource?.audio?.muted ?? false)
                          ? "" : ""
                    value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
                    onMoved: v => {
                        const s = Pipewire.defaultAudioSource?.audio
                        if (!s) return
                        s.muted = false
                        s.volume = v
                    }
                    onRightClicked: {
                        const s = Pipewire.defaultAudioSource?.audio
                        if (s) s.muted = !s.muted
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 1
                color: Colors.border; opacity: 0.5
                visible: streamsRepeater.count > 0
            }

            Text {
                text: "Applications"
                color: Colors.fgMuted
                font.family: Typography.fontSans
                font.pixelSize: Typography.fontMicro
                font.weight: Typography.weightMedium
                visible: streamsRepeater.count > 0
            }

            Repeater {
                id: streamsRepeater
                model: root.sinkStreams
                delegate: Column {
                    required property var modelData
                    readonly property PwNode node: modelData
                    width: body.width
                    spacing: Spacing.xs
                    Text {
                        text: {
                            const p = node?.properties
                            return (p ? p["application.name"] : undefined)
                                   || node?.description
                                   || node?.name
                                   || "Unknown"
                        }
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    SliderRow {
                        width: parent.width
                        icon: (node?.audio?.muted ?? false) ? "" : ""
                        value: node?.audio?.volume ?? 0
                        onMoved: v => {
                            if (!node?.audio) return
                            node.audio.muted = false
                            node.audio.volume = v
                        }
                        onRightClicked: {
                            if (node?.audio) node.audio.muted = !node.audio.muted
                        }
                    }
                }
            }
        }
    }

    // ─── Sticky footer: escape hatch → wiremix ────────────────────────
    footerComponent: Component {
        Column {
            width: parent.width
            spacing: 0

            Rectangle {
                width: parent.width
                height: Shape.borderThin
                color: Colors.border
                opacity: Effects.opacitySubtle
            }

            Rectangle {
                width: parent.width
                height: Sizing.px(44)
                color: wiremixMouse.containsMouse ? Colors.tileBgActive : "transparent"
                Behavior on color { CAnim { type: "fast" } }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Spacing.md
                    spacing: Spacing.sm
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        //  (fa-sliders-h) present in MesloLGS Nerd Font;
                        //  (nf-md-tune) is MISSING — replaced.
                        text: ""
                        color: Colors.fg
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontCaption
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Open wiremix"
                        color: Colors.fg
                        font.family: Typography.fontSans
                        font.pixelSize: Typography.fontCaption
                        font.weight: Typography.weightMedium
                    }
                }
                MouseArea {
                    id: wiremixMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Ui.closePopover()
                        Quickshell.execDetached(["arche-popup", "wiremix"])
                    }
                }
            }
        }
    }
}
