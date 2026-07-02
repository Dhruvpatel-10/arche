import QtQuick 2.15
import QtQuick.Window 2.15
import "components"

Rectangle {
    id: root
    width: Window.window ? Window.window.width : Screen.width
    height: Window.window ? Window.window.height : Screen.height
    color: config.bgColor

    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    property int selectedUserIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string selectedUserName: userModel.lastUser || ""
    property int selectedSessionIndex: sessionModel.lastIndex
    property bool busy: false

    // Multi-monitor: SDDM instantiates Main.qml per screen. Each instance has
    // independent state — typing/clicks don't cross screens. We render full
    // UI on every screen so the user can log in from whichever has focus.
    // (SDDM's `screenModel.geometry()` is a model role, not an invokable —
    // there is no reliable per-instance "am I the primary?" check, and
    // hiding UI on secondaries would orphan input on those screens.)

    function syncSelectedName() {
        var n = picker.userNameAt(root.selectedUserIndex)
        if (n && n.length > 0) root.selectedUserName = n
    }

    // Background: very faint amber wash for warmth.
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height) * 0.9
        height: width
        radius: width / 2
        opacity: 0.025
        color: config.accentColor
    }

    // Background boot log — top-left, fades down. Decorative.
    BootLog {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 38
        anchors.leftMargin: 32
        textColor: config.fgDim
        fontFamily: config.monoFontFamily
        visible: config.showBootLog === "true"
        z: 1
    }

    // Top-left: sysinfo, layered above boot log.
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 38
        anchors.leftMargin: 32
        spacing: 4
        z: 2

        Text {
            text: "host: " + (sddm.hostName || "arche")
            color: config.fgColor
            font.family: config.monoFontFamily
            font.pixelSize: 12
        }
        Text {
            text: "os:   arch linux"
            color: config.fgColor
            font.family: config.monoFontFamily
            font.pixelSize: 12
        }
        Text {
            text: "ui:   hyprland · wayland"
            color: config.fgColor
            font.family: config.monoFontFamily
            font.pixelSize: 12
        }
    }

    // Top-right: clock.
    Clock {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 38
        anchors.rightMargin: 40
        fontFamily: config.monoFontFamily
        textColor: config.fgColor
        mutedColor: config.fgMuted
        hourFormat: parseInt(config.hourFormat) || 24
        showSeconds: config.showSeconds === "true"
        z: 2
    }

    // Center login stack — left-shifted from screen center per design.
    Column {
        id: loginStack
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Math.max(80, root.width * 0.24)
        spacing: 28
        z: 3

        Text {
            text: "arche login —"
            color: config.fgMuted
            font.family: config.monoFontFamily
            font.pixelSize: 13
        }

        UserPicker {
            id: picker
            model: userModel
            selectedIndex: root.selectedUserIndex
            accentColor: config.accentColor
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            fgDim: config.fgDim
            fontFamily: config.monoFontFamily
            fontSize: 32

            onUserSelected: function(index, userName) {
                root.selectedUserIndex = index
                root.selectedUserName = userName
                prompt.clearPassword()
                prompt.forceFocus()
                errorText.text = ""
            }
        }

        Item { width: 1; height: 16 }

        PromptField {
            id: prompt
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            accentColor: config.accentColor
            errorColor: config.errorColor
            fontFamily: config.monoFontFamily
            fontSize: 18
            promptUser: root.selectedUserName.length > 0 ? root.selectedUserName : "user"
            promptHost: config.shellHost || "arche"
            busy: root.busy

            onSubmitted: root.attemptLogin()
            onPreviousUser: root.cyclePrevious()
            onNextUser: root.cycleNext()
        }

        Text {
            id: errorText
            text: ""
            color: config.errorColor
            font.family: config.monoFontFamily
            font.pixelSize: 12
            opacity: text.length > 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
    }

    // Bottom-left: keyboard layout indicator.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 32
        anchors.bottomMargin: 32
        text: {
            if (!keyboard || !keyboard.layouts || keyboard.layouts.length === 0) return "[--]"
            var i = keyboard.currentLayout
            if (i < 0 || i >= keyboard.layouts.length) return "[--]"
            var l = keyboard.layouts[i]
            return "[" + (l && l.shortName ? l.shortName.toLowerCase() : "--") + "]"
        }
        color: config.fgMuted
        font.family: config.monoFontFamily
        font.pixelSize: 11

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (keyboard && keyboard.layouts && keyboard.layouts.length > 0)
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // Bottom-right: power controls.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 28
        spacing: 24

        IconButton {
            glyph: "⏻"
            label: "POWEROFF"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            monoFamily: config.monoFontFamily
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }
        IconButton {
            glyph: "↻"
            label: "REBOOT"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            monoFamily: config.monoFontFamily
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }
        IconButton {
            glyph: "☾"
            label: "SUSPEND"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            monoFamily: config.monoFontFamily
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false
            errorText.text = ""
        }

        function onLoginFailed() {
            root.busy = false
            errorText.text = "auth: incorrect password"
            prompt.clearPassword()
            prompt.forceFocus()
        }

        function onInformationMessage(message) {
            errorText.text = message
        }
    }

    function attemptLogin() {
        if (!root.selectedUserName) return
        root.busy = true
        errorText.text = ""
        sddm.login(root.selectedUserName, prompt.text, root.selectedSessionIndex)
    }

    function cyclePrevious() {
        var n = userModel.count
        if (n <= 1) return
        var idx = root.selectedUserIndex - 1
        if (idx < 0) idx = n - 1
        root.selectedUserIndex = idx
        root.syncSelectedName()
        prompt.clearPassword()
    }

    function cycleNext() {
        var n = userModel.count
        if (n <= 1) return
        var idx = (root.selectedUserIndex + 1) % n
        root.selectedUserIndex = idx
        root.syncSelectedName()
        prompt.clearPassword()
    }

    Component.onCompleted: {
        root.syncSelectedName()
        prompt.forceFocus()
    }
}
