import Quickshell
import "."
import "./components"
import "./osd"

ShellRoot {
    // Per-screen top bar.
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Drawers (one PanelWindow each for now).
    ControlCenter {}
    CalendarPanel {}
    ToastLayer {}
    ClipboardPicker {}

    // Per-screen OSD overlay.
    Variants {
        model: Quickshell.screens
        OsdOverlay {}
    }

    // External triggers — all IpcHandler targets live in Shortcuts.qml.
    Shortcuts {}
}
