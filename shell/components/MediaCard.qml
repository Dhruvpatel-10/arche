import QtQuick
import Quickshell.Services.Mpris
import "../theme"

// MediaCard — compact "now playing" tile for the control center drawer.
//
// Player selection is an explicit multi-step binding, not a chained
// `.find() ?? values[0] ?? null`. Two reasons:
//   1) `Mpris.players` is a QML model; its `.values` proxy changes on
//      every player add/remove. The binding re-evaluates on that signal,
//      so we always resolve against the *current* list — no cached refs.
//   2) Explicit iteration makes it obvious that null is the intended
//      empty state (no players at all), which drives `visible` below.
//
// Pitfall #12: never cache `MprisPlayer` references across model resets.
// The binding below is derived, not cached — each re-evaluation hands
// back a fresh reference from the live model.
Rectangle {
    id: root

    readonly property MprisPlayer player: {
        const list = Mpris.players?.values
        if (!list || list.length === 0) return null
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying) return list[i]
        return list[0]
    }

    implicitHeight: Sizing.px(72)
    color: Colors.bgAlt
    radius: Shape.radiusTile
    visible: player !== null
    clip: true

    // Nudge MPRIS players that don't emit positionChanged on a schedule.
    // Quickshell's MprisPlayer docs sanction calling `positionChanged()` as
    // a manual poll — Quickshell then re-reads `player.position` off the
    // bus. Without this, VLC / mpv / some browsers stop updating position
    // between metadata changes and the progress bar freezes. Cheap: one
    // D-Bus round-trip per second while a player is actively playing.
    Timer {
        interval: 1000
        running: root.visible && (root.player?.isPlaying ?? false)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    Row {
        anchors {
            fill: parent
            leftMargin: Spacing.md
            rightMargin: Spacing.md
        }
        spacing: Spacing.md

        // Album art with placeholder fallback while loading / missing.
        // Wrapper Rectangle owns the radius + clip so the art rounds to
        // the same corner as the placeholder — otherwise Ready art drew
        // sharp corners against a rounded surface.
        Rectangle {
            id: art
            width: Sizing.px(52)
            height: Sizing.px(52)
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.tileBg
            radius: Shape.radiusSm
            clip: true

            Image {
                id: artImg
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        // Title + artist column. Width computed so the controls row on
        // the right never wraps: total - art - margins - controls.
        Column {
            width: parent.width - art.width - controls.width - Spacing.md * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Spacing.xs

            Text {
                text: root.player?.trackTitle ?? "Nothing playing"
                color: Colors.fg
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontBody
                    weight: Font.DemiBold
                }
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.player?.trackArtist ?? ""
                color: Colors.fgMuted
                font {
                    family: Typography.fontSans
                    pixelSize: Typography.fontCaption
                }
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // Transport controls. Height matches the largest child so the
        // row's verticalCenter aligns with the play button.
        Row {
            id: controls
            width: Sizing.px(108)
            height: Sizing.px(40)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Spacing.xs

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf048"
                iconSize: Sizing.fpx(11)
                onClicked: root.player?.previous()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: Sizing.px(40)
                height: Sizing.px(40)
                radius: width / 2
                color: Colors.fg
                iconColor: Colors.bgAlt
                icon: root.player?.isPlaying ? "\uf04c" : "\uf04b"
                iconSize: Sizing.fpx(14)
                onClicked: root.player?.togglePlaying()
            }
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\uf051"
                iconSize: Sizing.fpx(11)
                onClicked: root.player?.next()
            }
        }
    }

    // Thin progress strip along the bottom edge. Hidden when the player
    // doesn't report position / length so it doesn't hang at 0 for
    // streams or ad-hoc sources.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Sizing.px(2)
        color: Colors.border
        opacity: Effects.opacitySubtle
        visible: (root.player?.length ?? 0) > 0

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * Math.max(0, Math.min(1,
                (root.player?.position ?? 0) / (root.player?.length ?? 1)))
            color: Colors.accent
            Behavior on width { Anim { type: "fast" } }
        }
    }
}
