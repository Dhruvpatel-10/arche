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

    // Split-notch bar — three per-screen layer windows that together
    // form the living-notch panel. Wings hug the corners; the Island
    // floats between them and morphs by state. See components/*Wing.qml
    // and components/IslandWindow.qml.
    Variants {
        model: Quickshell.screens
        BarLeftWing {}
    }
    Variants {
        model: Quickshell.screens
        IslandWindow {}
    }
    Variants {
        model: Quickshell.screens
        BarRightWing {}
    }

    // Drawers (one PanelWindow each for now).
    ControlCenter {}
    CalendarPanel {}
    ToastLayer {}
    ClipboardPicker {}
    PowerMenuDialog {}
    LauncherDialog {}

    // Per-pill focused popovers — one per screen so each monitor gets
    // its own scrim / focus-grab pair. Mutually exclusive via the single
    // `Ui.rightPopover` string.
    Variants { model: Quickshell.screens; NotificationsPopover {} }
    Variants { model: Quickshell.screens; AudioMixerPopover    {} }
    Variants { model: Quickshell.screens; NetworkPopover       {} }
    Variants { model: Quickshell.screens; BluetoothPopover     {} }
    Variants { model: Quickshell.screens; BatteryPopover       {} }

    // Per-screen OSD overlay.
    Variants {
        model: Quickshell.screens
        OsdOverlay {}
    }

    // External triggers — all IpcHandler targets live in Shortcuts.qml.
    Shortcuts {}
}
