import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import ".."
import "../services"
import "../theme"

// NowPlayingStrip — inline bar-resident media indicator. Lives INSIDE
// the Bar's left cluster alongside the workspace tiles, not in its
// own peripheral PanelWindow (which was the retired MediaPill). The bar
// stays one flat strip; app content falls cleanly below it without a
// pill protruding into the workspace area.
//
// Scope is deliberately narrow:
//   • text-only (♪ glyph + elided title)
//   • no album art, no hover-grow, no inline transport
//   • clicking toggles MediaPopover (compact card anchored below)
//
// Transport / scrubber live in the MediaPopover. The strip is pure
// awareness — "something is playing, here's what".
//
// VISIBILITY GATE: the strip hides entirely on idle — when no MPRIS
// player is registered, or when the active player has no track loaded
// (Stopped state / empty trackTitle). Playing AND Paused both count as
// "active" so the strip doesn't flicker when the user briefly pauses.
// The parent Row respects `visible: false` → the element contributes
// zero advance width when idle, so the bar's left cluster tightens
// cleanly when nothing is playing.
//
// NO CACHED PLAYER REFERENCE (pitfall #12): `player` is a live binding
// that re-evaluates on every Mpris.players model reset. Pinned identity
// wins; otherwise prefer any playing player; otherwise first in list.
//
// Per-screen scale: `screenName` is forwarded by the Bar so
// Sizing.pxFor/fpxFor honor ARCHE_SHELL_LAYOUT_SCALE_<name>.
Item {
    id: root

    // Screen name forwarded from Bar for per-screen Sizing.
    property string screenName: ""

    // Supplied by Bar so the title color can follow the wallpaper-adaptive
    // foreground palette. When the surface is opaque (fullscreen under
    // the bar) we always use the dark-surface fg; when translucent AND
    // the wallpaper is light, we flip to Colors.fgOnLight for AA contrast.
    property bool hasFullscreen: false
    readonly property bool _useLight:
        !hasFullscreen && WallpaperContrast.isLight
    readonly property color _fgPrimary: _useLight ? Colors.fgOnLight : Colors.fg

    // Live binding — never cache. pinned > playing > first.
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

    // Idle detection: hide when no player OR the active player has nothing
    // loaded. MprisPlaybackState: Playing (2), Paused (1), Stopped (0). We
    // show for Playing and Paused, hide for Stopped/unknown. Title check
    // guards against players that report Paused with an empty slot.
    readonly property bool hasActiveMedia: {
        if (!player) return false
        if (!player.trackTitle) return false
        return player.playbackState !== MprisPlaybackState.Stopped
    }
    visible: hasActiveMedia

    // Layout contract: the Bar's left cluster Row lays us out based on
    // these. Height matches the workspace tile row (20 px at base scale);
    // width is the inner Row's natural content width.
    implicitHeight: Sizing.pxFor(20, screenName)
    implicitWidth: innerRow.implicitWidth

    // ─── Inner content row ────────────────────────────────────────────
    Row {
        id: innerRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: Spacing.sm

        // Thin divider — matches the right-cluster separator style so the
        // whole bar uses one visual vocabulary for "section break".
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Sizing.pxFor(1.5, root.screenName)
            height: Sizing.pxFor(14, root.screenName)
            color: Colors.separator
            opacity: Effects.opacitySubtle
        }

        // Music glyph — amber to pick up the Ember accent.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf001"   // nf-fa-music
            color: Colors.accent
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontCaption
        }

        // Title clamp — cap width so a long track title can't blow the
        // bar out horizontally. Over the cap, elide. Under it, the Item
        // shrinks to the Text's natural width so short titles don't
        // reserve unused space.
        //
        // implicitWidth is independent of width (it derives from text +
        // font metrics), so the Math.min feedback loop is safe.
        Item {
            id: titleClamp
            anchors.verticalCenter: parent.verticalCenter
            readonly property int capW: Sizing.pxFor(220, root.screenName)
            width: Math.min(titleText.implicitWidth, capW)
            height: titleText.implicitHeight

            Text {
                id: titleText
                anchors.fill: parent
                text: root.player?.trackTitle ?? ""
                color: root._fgPrimary
                font.family: Typography.fontMono
                font.pixelSize: Typography.fontCaption
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                Behavior on color { CAnim { type: "standard" } }
            }
        }
    }

    // ─── Click → open / close MediaPopover ───────────────────────────
    // Click-only trigger. We previously had a hover chain (strip +
    // card + grace timer) summoning the popover on hover; it was
    // removed because the card-sliding-through-cursor race (see
    // quickshell-notes.md → "Hover-triggered popovers, retired") was
    // impossible to make clean — every mitigation introduced another
    // edge case (gated handler deadzone, counter drift). Neither
    // caelestia nor noctalia uses a bar-inline hover-triggered media
    // popover; both expose media through click-accessed surfaces. We
    // align with that.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.mediaPopoverOpen = !Ui.mediaPopoverOpen
    }
}
