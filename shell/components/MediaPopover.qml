import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import ".."
import "../theme"

// MediaPopover — compact now-playing popover anchored under the inline
// NowPlayingStrip in the unified Bar. Renamed from MediaDialog (the old
// name was a misnomer — this is not a modal dialog, it's a click-anchored
// popover that slides below the bar).
//
// Built on ArcheDialog { mode: "popover"; anchorEdge: "left" }. Every
// window-level concern — scrim click-outside, Esc, focused-monitor
// teleport, slide/fade animation — lives on the base. See ArcheDialog.qml.
//
// TRIGGER — click only. Previous attempt: hover-to-open (strip + card
// hovers ORed together, 300 ms grace timer, HoverHandler gated on
// animation rest). It was not clean: the card sliding past a stationary
// cursor raced hit-tests, and the "enabled while offsetScale === 0" gate
// produced a deadzone where re-entering mid-animation couldn't register.
// Neither caelestia nor noctalia uses a bar-inline hover-triggered media
// popover. See docs/quickshell-notes.md → "Hover-triggered popovers,
// retired".
//
// Ui.mediaPopoverOpen is the sole user-intent flag:
//   • Clicking the strip toggles it.
//   • `qs ipc call media popoverToggle` (or back-compat `dialogToggle`)
//     flips it from keybinds.
//   • Escape / click-outside close it (via ArcheDialog's scrim + Esc).
//
// DESIGN — minimal: header + art + title/artist + scrubber + transport +
// volume. No output-sink picker, no shuffle/loop — run
// `arche-popup wiremix` for full sink management.
ArcheDialog {
    id: root
    name: "media"

    mode:       "popover"
    anchorEdge: "left"

    // Align the card under the NowPlayingStrip. Left inset at Spacing.md
    // matches the inline strip's own left padding at typical workspace
    // counts. Top offset (bar height + xs) is inherited from ArcheDialog's
    // default — every arche popover hangs below the bar, so the base owns
    // that number.
    anchorSideMargin: Spacing.md

    // Compact card — one line each for title / artist / scrubber, with a
    // 72×72 art tile on the left.
    cardWidth: Sizing.px(360)

    // ─── Player selection (pitfall #12 — never cache) ────────────────
    readonly property MprisPlayer player: {
        const list = Mpris.players?.values
        if (!list || list.length === 0) return null
        if (Ui.pinnedPlayerIdentity !== "") {
            const pinned = list.find(p => p.identity === Ui.pinnedPlayerIdentity)
            if (pinned) return pinned
        }
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i]
        return list[0]
    }

    readonly property bool hasActiveMedia: {
        if (!player) return false
        if (!player.trackTitle) return false
        return player.playbackState !== MprisPlaybackState.Stopped
    }

    // Open gate — user intent AND a live player. If a player dies while
    // the popover is open, the binding naturally pulls `open` back to
    // false and the card slides out.
    open: hasActiveMedia && Ui.mediaPopoverOpen
    onDismissed: Ui.mediaPopoverOpen = false

    // ─── Position-nudge Timer ────────────────────────────────────────
    // Some MPRIS players (VLC, mpv, some browsers) don't emit
    // positionChanged on a regular schedule. Poking `positionChanged()`
    // causes Quickshell to re-read position over D-Bus, keeping the
    // scrubber live. Scoped to visible+playing — no poll while hidden
    // or paused.
    Timer {
        interval: 1000
        running: root.visible && (root.player?.isPlaying ?? false)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    // ─── Time formatter ──────────────────────────────────────────────
    function fmt(seconds): string {
        const s = Math.max(0, Math.floor(seconds))
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ─── Card content ────────────────────────────────────────────────
    // Column spans the content area; `height: implicitHeight` feeds the
    // popover card-height chain (ArcheDialog reads childrenRect.height).
    Column {
        id: cardColumn
        anchors.left:  parent.left
        anchors.right: parent.right
        height: implicitHeight
        spacing: Spacing.md

        // ─── Header ──────────────────────────────────────────────
        Row {
            spacing: Spacing.sm
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf001"
                color: Colors.accent
                font.family: Typography.fontMono
                font.pixelSize: Typography.fontCaption
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Now playing"
                color: Colors.fgMuted
                font.family: Typography.fontSans
                font.pixelSize: Typography.fontCaption
                font.weight: Typography.weightMedium
            }
            // Small pin indicator when user has pinned the popover via
            // click / IPC. Purely informational — unpinning is via
            // clicking the strip again, Esc, or IPC close.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Ui.mediaPopoverOpen
                text: "\uf08d"   // nf-fa-thumb_tack
                color: Colors.fgDim
                font.family: Typography.fontMono
                font.pixelSize: Typography.fontMicro
            }
        }

        // ─── Art + title/artist/scrubber row ─────────────────────
        Row {
            width: parent.width
            spacing: Spacing.md

            // Album art — small square with fallback glyph.
            Rectangle {
                id: art
                width: Sizing.px(72)
                height: Sizing.px(72)
                radius: Shape.radiusNormal
                color: Colors.tileBg
                clip: true

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    text: "\uf001"
                    color: Colors.fgDim
                    font.family: Typography.fontMono
                    font.pixelSize: Sizing.fpx(22)
                    visible: artImage.status !== Image.Ready
                }
            }

            // Title + artist + scrubber stacked.
            Column {
                width: parent.width - art.width - parent.spacing
                spacing: Spacing.xs
                anchors.verticalCenter: parent.verticalCenter

                // Title — bold, elided at card width.
                Text {
                    width: parent.width
                    text: root.player?.trackTitle ?? ""
                    color: Colors.fg
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontBody
                    font.weight: Typography.weightDemiBold
                    elide: Text.ElideRight
                }

                // Artist — muted, single line.
                Text {
                    width: parent.width
                    text: root.player?.trackArtist ?? ""
                    color: Colors.fgMuted
                    font.family: Typography.fontSans
                    font.pixelSize: Typography.fontCaption
                    elide: Text.ElideRight
                    visible: text.length > 0
                }

                // Scrubber — slim progress bar + inline times. Only
                // shown when the player exposes a non-zero length (some
                // streams / web players lie about length).
                Item {
                    width: parent.width
                    height: Sizing.px(14)
                    visible: (root.player?.length ?? 0) > 0

                    Slider {
                        id: scrubber
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        // Zero the Qt Controls default paddings so the
                        // track spans the Slider's full width (sibling
                        // time labels anchor to parent.left/right;
                        // mismatched paddings caused the scrubber to
                        // inset while labels stayed flush — see
                        // docs/quickshell-notes.md).
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        from: 0
                        to: root.player?.length ?? 0
                        value: root.player?.position ?? 0
                        enabled: root.player?.canSeek ?? false
                        onMoved: {
                            if (root.player) root.player.position = value
                        }

                        background: Rectangle {
                            x: scrubber.leftPadding
                            y: scrubber.topPadding
                               + scrubber.availableHeight / 2 - height / 2
                            width: scrubber.availableWidth
                            height: Sizing.px(3)
                            radius: height / 2
                            color: Colors.bgAlt

                            Rectangle {
                                width: scrubber.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: Colors.accent
                            }
                        }
                        handle: Rectangle {
                            x: scrubber.leftPadding
                               + scrubber.visualPosition
                               * (scrubber.availableWidth - width)
                            y: scrubber.topPadding
                               + scrubber.availableHeight / 2 - height / 2
                            width: Sizing.px(10); height: Sizing.px(10)
                            radius: width / 2
                            color: Colors.fg
                            visible: scrubber.enabled && scrubberHover.hovered
                        }

                        HoverHandler { id: scrubberHover }
                    }
                }

                // Time readouts — sit directly below the scrubber.
                Item {
                    width: parent.width
                    height: posLabel.implicitHeight
                    visible: (root.player?.length ?? 0) > 0

                    Text {
                        id: posLabel
                        anchors.left: parent.left
                        text: root.fmt(root.player?.position ?? 0)
                        color: Colors.fgMuted
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        anchors.right: parent.right
                        text: root.fmt(root.player?.length ?? 0)
                        color: Colors.fgMuted
                        font.family: Typography.fontMono
                        font.pixelSize: Typography.fontMicro
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        // ─── Transport ───────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Spacing.lg

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf048"
                iconSize: Sizing.fpx(13)
                onClicked: root.player?.previous()
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Sizing.px(44); height: Sizing.px(44)
                radius: width / 2
                color: Colors.fg

                Text {
                    anchors.centerIn: parent
                    text: root.player?.isPlaying ? "\uf04c" : "\uf04b"
                    color: Colors.bgAlt
                    font.family: Typography.fontMono
                    font.pixelSize: Sizing.fpx(15)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.togglePlaying()
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf051"
                iconSize: Sizing.fpx(13)
                onClicked: root.player?.next()
            }
        }

        // ─── Thin divider before volume ─────────────────────────
        Rectangle {
            width: parent.width; height: 1
            color: Colors.border
            opacity: Effects.opacitySubtle
        }

        // ─── Master volume ──────────────────────────────────────
        // SliderRow matches AudioMixerPopover exactly — one volume
        // idiom across the shell.
        SliderRow {
            width: parent.width
            icon: (Pipewire.defaultAudioSink?.audio?.muted ?? false)
                  ? "\uf026" : "\uf028"
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

    // Keep the default-sink audio properties alive so the volume
    // binding doesn't flap when the default sink changes.
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
}
