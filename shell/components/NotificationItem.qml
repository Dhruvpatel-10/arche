import QtQuick
import Quickshell
import ".."
import "../theme"

// NotificationItem — single row in the notifications list. Icon disc on
// the left, summary / body / meta in the middle, dismiss X on the right.
// Click body to trigger the default action; Meta-click to dismiss without
// invoking the app.
//
// HEIGHT IS CONTENT-DRIVEN. A fixed implicitHeight (the old `Sizing.px(58)`
// literal) caused cards with multi-line bodies to overflow their own slot,
// so the Column centered inside each card would paint over the neighbours
// in the enclosing list's Column layout. Now the card's implicitHeight
// follows the text column, clamped to a sensible minimum so single-line
// notifications still read as a row (not a cramped pill). Body is wrapped
// and capped to `maxBodyLines` so one monster notification can't take over
// the entire popover.
//
// ICON RESOLUTION — three-tier fallback (caelestia's idiom, adapted):
//   1. `entry.image`   hero image (Slack avatar, album art, screenshot
//                      preview) — shown as the primary tile, filled crop.
//   2. `entry.appIcon` freedesktop icon name or absolute path, resolved
//                      via `Quickshell.iconPath(...)`. Path → direct load;
//                      name → theme lookup. Falls back to appName (lower-
//                      cased) as a last theme query before the glyph.
//   3. bell glyph      accent-tinted disc — the "notification arrived"
//                      fallback when nothing else resolves.
//
// Motion uses the shared Anim / CAnim presets so hover recolor and
// dismiss-fade match the rest of the shell — no bespoke durations.
Rectangle {
    id: root
    required property var entry

    // Hover state — driven by hoverArea.containsMouse so the close button
    // reveal is in one place. Visible-binding on the button kills the
    // hit-test at rest (no phantom click targets when not hovered).
    property bool _hovered: false

    // Layout tokens — kept as readonly properties rather than magic numbers
    // so a size tweak stays in one place and the textCol width expression
    // below stays readable.
    readonly property int padV:      Spacing.sm
    readonly property int padH:      Spacing.md
    readonly property int iconSize:  Sizing.px(40)
    readonly property int closeSize: Sizing.px(22)
    readonly property int gap:       Spacing.md

    // At most two lines of body text; anything beyond elides. Two lines is
    // enough to preview a short Slack/IRC message without letting a bug
    // report paste eat the entire popover.
    readonly property int maxBodyLines: 2

    // ─── Icon resolution ──────────────────────────────────────────────
    // Paths start with '/', names don't. Quickshell.iconPath handles both
    // but returns "" on miss; we tier the fallbacks so a missing appIcon
    // on a Slack notification still picks up the appName-themed icon
    // before dropping to the glyph.
    readonly property string _image: (entry && typeof entry.image === "string")
                                     ? entry.image : ""
    readonly property string _iconName: (entry && typeof entry.appIcon === "string")
                                        ? entry.appIcon : ""
    readonly property string _appKey: (entry && typeof entry.appName === "string")
                                      ? entry.appName.toLowerCase().replace(/\s+/g, "-")
                                      : ""
    readonly property string _resolvedAppIcon: {
        if (!_iconName) {
            return _appKey ? Quickshell.iconPath(_appKey, "") : ""
        }
        const primary = Quickshell.iconPath(_iconName, "")
        if (primary) return primary
        return _appKey ? Quickshell.iconPath(_appKey, "") : ""
    }
    readonly property bool _hasImage: _image.length > 0
    readonly property bool _hasAppIcon: _resolvedAppIcon.length > 0

    function relativeTime(ms) {
        const diff = Math.max(0, Date.now() - ms)
        const m = Math.floor(diff / 60000)
        if (m < 1) return "just now"
        if (m < 60) return m + "m ago"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h ago"
        return Math.floor(h / 24) + "d ago"
    }

    function defaultAction() {
        // Remove first so the UI updates instantly; satty's cold start then
        // happens in the background without the panel feeling stuck.
        const appName = entry.appName
        const appIcon = entry.appIcon
        const body = entry.body
        Notifs.removeFromHistory(entry)
        Notifs.invokeDefault(appName, appIcon, body)
    }

    // Content-driven height. `textCol.implicitHeight` is the sum of the
    // visible Text implicitHeights + their spacing; padding is added once on
    // each side. The `Sizing.px(60)` floor keeps the single-line empty-body
    // case looking like a proper row, not a cramped sliver.
    implicitHeight: Math.max(Sizing.px(60),
                             textCol.implicitHeight + padV * 2)

    color: hoverArea.containsMouse ? Colors.tileBgActive : Colors.tileBg
    radius: Shape.radiusNormal
    opacity: entry.dismissed ? Effects.opacityMuted : 1.0

    Behavior on opacity { Anim  { type: "fast" } }
    Behavior on color   { CAnim { type: "fast" } }

    // Icon disc — anchored left, vertically centered so it reads as a
    // badge regardless of how many body lines the text column grows to.
    //
    // Three layers, painted in resolution order: hero image (if present),
    // app icon (if resolved), glyph fallback. Each higher tier hides the
    // one below via `visible`. The disc itself paints the accent-tinted
    // ground that shows through transparent icons (KDE symbolic SVGs).
    Rectangle {
        id: iconDisc
        width:  root.iconSize
        height: root.iconSize
        radius: width / 2
        color: root._hasImage
               ? Colors.bgAlt
               : root._hasAppIcon
                 ? Colors.bgSurface
                 : Colors.accent
        anchors.left:           parent.left
        anchors.leftMargin:     root.padH
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        // Hero image — Slack avatar, album art, satty screenshot preview.
        // PreserveAspectCrop fills the disc; a short-form image won't get
        // letterboxed into a tiny pill.
        Image {
            id: heroImage
            anchors.fill: parent
            source: root._hasImage ? root._image : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root._hasImage && status === Image.Ready
        }

        // App icon — inset so the themed icon doesn't kiss the disc edge.
        // PreserveAspectFit preserves square icons; `smooth` for downscale
        // quality on dense displays.
        Image {
            id: appIconImage
            anchors.fill: parent
            anchors.margins: Sizing.px(8)
            source: (!root._hasImage && root._hasAppIcon)
                    ? root._resolvedAppIcon
                    : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            cache: true
            visible: !root._hasImage
                     && root._hasAppIcon
                     && status === Image.Ready
        }

        // Glyph fallback — only paints when nothing else resolved. Bell
        // tinted on accent-ground reads as "notification", not "icon
        // loading".
        Text {
            anchors.centerIn: parent
            text: "\uf0f3"
            color: Colors.bgAlt
            font.family: Typography.fontMono
            font.pixelSize: Typography.fontLabel
            visible: !heroImage.visible && !appIconImage.visible
        }
    }

    // Text column — spans from the icon disc to the close button, vertically
    // centered. Driving the card's height from `textCol.implicitHeight` (see
    // implicitHeight above) means growing the body to 2 lines grows the card
    // with it; the list's enclosing Column then lays out items without
    // overlap.
    Column {
        id: textCol
        anchors.left:           iconDisc.right
        anchors.leftMargin:     root.gap
        anchors.right:          closeBtn.left
        anchors.rightMargin:    root.gap
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            text:  root.entry.summary
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
            text:  root.entry.body
            color: Colors.fgMuted
            font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
            // Wrap body across multiple lines instead of the single-line
            // elide the previous fixed-height layout was forced into.
            wrapMode: Text.WordWrap
            maximumLineCount: root.maxBodyLines
            elide: Text.ElideRight
            width: parent.width
            visible: text.length > 0
        }
        Text {
            text:  (root.entry.appName || "")
                   + (root.entry.appName ? " · " : "")
                   + root.relativeTime(root.entry.time)
            color: Colors.fgDim
            font { family: Typography.fontSans; pixelSize: Typography.fontCaption }
            elide: Text.ElideRight
            width: parent.width
        }
    }

    // Close button — anchored right, vertically centered. Declared after
    // textCol so it paints on top of anything that accidentally bleeds into
    // its bounds during hover transitions.
    //
    // Hover-reveal: opacity and visible both bind to _hovered. The visible
    // binding eliminates the hit-test at rest (no accidental dismiss clicks
    // on non-hovered rows). Opacity Behavior gives a smooth fade.
    IconButton {
        id: closeBtn
        width:  root.closeSize
        height: root.closeSize
        radius: width / 2
        icon: "\uf00d"
        iconSize: Sizing.fpx(9)
        color: "transparent"
        anchors.right:          parent.right
        anchors.rightMargin:    root.padH
        anchors.verticalCenter: parent.verticalCenter
        visible: root._hovered
        opacity: root._hovered ? 1.0 : 0.0
        Behavior on opacity { Anim { type: "fast" } }
        onClicked: Notifs.removeFromHistory(root.entry)
    }

    // Body hover / default-action handler. Sits BEHIND the close button
    // (declared first, default z=0 → earlier-declared = lower Z). Excludes
    // the close-button column so a click that falls on the X actually
    // dismisses instead of triggering the default action.
    //
    // containsMouse drives root._hovered which in turn controls closeBtn
    // opacity and visibility — one source of truth, no racing.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: -1
        onContainsMouseChanged: root._hovered = containsMouse
        onClicked: (mouse) => {
            if (mouse.modifiers & Qt.MetaModifier) {
                Notifs.removeFromHistory(root.entry)
            } else {
                root.defaultAction()
            }
        }
    }
}
