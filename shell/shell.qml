import Quickshell
import "."
import "./components"
import "./osd"
import "./services"

ShellRoot {
    // Force-instantiate side-effect singletons. QML singletons are lazy —
    // they only construct on first reference. IdleInhibitor binds a
    // systemd-inhibit Process to `Ui.caffeineOn`; without a reference here
    // nothing would keep it alive and the caffeine toggle would silently
    // no-op. One-line touch per side-effect service — no behaviour wired.
    readonly property var _caffeine: IdleInhibitor
    // IdleLock owns hypridle's lifecycle (start/stop driven by `enabled`)
    // and registers IPC `idle`. Without a reference here the singleton
    // would never construct, autostart wouldn't fire, and the keybind
    // would no-op.
    readonly property var _idleLock: IdleLock

    // Bar — one full-width layer surface per screen, macOS-style. See
    // components/Bar.qml for the composition + adaptive-surface story
    // (the bar's color tracks wallpaper luminance via WallpaperContrast
    // and crossfades to opaque under fullscreen apps).
    //
    // Previously this was a three-wing split (BarLeftWing + BarCenterWing
    // + BarRightWing) plus a separate BarExclusionZone that reserved
    // the top edge. The unified Bar owns its own exclusive zone and
    // composes the three clusters (BarWorkspaces + NowPlayingStrip on
    // the left, BarClock centered, BarStatusPills on the right) as
    // anchored children. The retired wings and exclusion layer have
    // been deleted; see docs/quickshell-notes.md → "Bar exclusion zone"
    // for the why.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Drawers (one PanelWindow each for now). MediaPopover follows the
    // focused monitor (like CalendarPanel) so "full music" always opens
    // where the user is looking. It's launched by clicking the inline
    // NowPlayingStrip in the Bar or via IPC (`qs ipc call media
    // popoverToggle`).
    ControlCenter {}
    CalendarPanel {}
    MediaPopover {}
    ToastLayer {}
    ClipboardPicker {}
    PowerMenuDialog {}
    LauncherDialog {}

    // Per-pill focused popovers — single instance each, rendered on the
    // Hyprland-focused monitor (same pattern as MediaPopover + CalendarPanel).
    // Per-screen Variants would paint the popover on every monitor at once
    // when its flag flips, because every instance would bind to the same
    // global `Ui.rightPopover` string. Single instance + focused-monitor
    // teleport keeps the popover where the user is looking. Mutually
    // exclusive via `Ui.rightPopover`.
    NotificationsPopover {}
    AudioMixerPopover    {}
    NetworkPopover       {}
    BluetoothPopover     {}
    BatteryPopover       {}

    // Per-screen OSD overlay.
    Variants {
        model: Quickshell.screens
        OsdOverlay {}
    }

    // External triggers — all IpcHandler targets live in Shortcuts.qml.
    Shortcuts {}
}
