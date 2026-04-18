import QtQuick 2.15
import QtQuick.Window 2.15
import "components"

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.bgColor

    LayoutMirroring.enabled: Qt.locale().textDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // ─── Selection state ───
    property int selectedUserIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string selectedUserName: userModel.lastUser || ""
    property string selectedRealName: ""
    property int selectedSessionIndex: sessionModel.lastIndex
    property bool busy: false

    // ─── Background: soft vertical gradient for depth ───
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: config.bgColor }
            GradientStop { position: 1.0; color: config.bgColorAlt }
        }
    }

    // Background image — only instantiated when theme.conf provides a path, so
    // an empty `background=` doesn't trigger a QML "Cannot open file:///…" error.
    Loader {
        id: backgroundLoader
        anchors.fill: parent
        active: config.background && config.background.length > 0
        sourceComponent: Image {
            source: config.background
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            opacity: 0.55
            asynchronous: true
            smooth: true
        }
    }

    // Faint amber wash — warmth without dominance. Hidden if a wallpaper is set.
    Rectangle {
        anchors.centerIn: parent
        width: Math.max(parent.width, parent.height) * 0.9
        height: width
        radius: width / 2
        opacity: 0.04
        color: config.accentColor
        visible: !backgroundLoader.active
                 || (backgroundLoader.item && backgroundLoader.item.status !== Image.Ready)
    }

    // ─── Top bar: hostname left, clock right ───
    Text {
        id: hostnameText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 40
        text: sddm.hostName || ""
        color: config.fgMuted
        font.family: config.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
        opacity: 0.8
        visible: config.showHostname === "true"
    }

    Clock {
        id: clock
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 40
        fontFamily: config.fontFamily
        monoFamily: config.monoFontFamily
        textColor: config.fgColor
        mutedColor: config.fgMuted
        hourFormat: parseInt(config.hourFormat) || 24
    }

    // ─── Center stack: users + greeting + password ───
    Column {
        id: centerStack
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1000)
        spacing: 44

        // User row (horizontal, scrollable if many)
        Flickable {
            id: userFlick
            width: parent.width
            height: 180
            contentWidth: userRow.implicitWidth
            contentHeight: userRow.implicitHeight
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: userRow
                height: parent.height
                spacing: 28
                anchors.horizontalCenter: userRow.implicitWidth < userFlick.width
                                          ? parent.horizontalCenter : undefined

                Repeater {
                    id: userRepeater
                    model: userModel

                    delegate: UserCard {
                        userName: model.name
                        realName: (model.realName !== undefined && model.realName.length > 0) ? model.realName : model.name
                        selected: index === root.selectedUserIndex
                        accentColor: config.accentColor
                        surfaceColor: config.surfaceColor
                        borderColor: config.borderColor
                        fgColor: config.fgColor
                        fgMuted: config.fgMuted
                        fontFamily: config.fontFamily
                        avatarSize: parseInt(config.avatarSize) || 112

                        Component.onCompleted: {
                            if (index === root.selectedUserIndex) {
                                root.selectedUserName = userName
                                root.selectedRealName = realName
                            }
                        }

                        onClicked: {
                            root.selectedUserIndex = index
                            root.selectedUserName = userName
                            root.selectedRealName = realName
                            passwordField.clearPassword()
                            passwordField.forceFocus()
                            errorText.text = ""
                        }
                    }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.selectedRealName.length > 0
                      ? "Welcome back, " + root.selectedRealName
                      : (root.selectedUserName.length > 0 ? "Welcome back, " + root.selectedUserName : "")
                color: config.fgMuted
                font.family: config.fontFamily
                font.pixelSize: 13
                font.weight: Font.Normal
                opacity: 0.85
                visible: text.length > 0
            }

            PasswordField {
                id: passwordField
                width: 380
                accentColor: config.accentColor
                surfaceColor: config.surfaceColor
                borderColor: config.borderColor
                fgColor: config.fgColor
                fgMuted: config.fgMuted
                fontFamily: config.fontFamily
                placeholder: "Enter password"
                radius: parseInt(config.radius) || 14
                busy: root.busy

                onSubmitted: root.attemptLogin()
            }

            Text {
                id: errorText
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: config.errorColor
                font.family: config.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                opacity: text.length > 0 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }

    // ─── Bottom-left: session + layout chips ───
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 10

        Chip {
            id: sessionChip
            label: "Session"
            value: "#" + (root.selectedSessionIndex + 1) + " / " + sessionModel.rowCount()
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            surfaceColor: config.surfaceColor
            borderColor: config.borderColor
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            visible: sessionModel.rowCount() > 1

            onClicked: {
                root.selectedSessionIndex = (root.selectedSessionIndex + 1) % sessionModel.rowCount()
            }
        }

        Chip {
            label: "Layout"
            value: {
                if (!keyboard || !keyboard.layouts || keyboard.layouts.length === 0) return ""
                var i = keyboard.currentLayout
                if (i < 0 || i >= keyboard.layouts.length) return ""
                var l = keyboard.layouts[i]
                return (l && l.shortName) ? l.shortName : ""
            }
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            surfaceColor: config.surfaceColor
            borderColor: config.borderColor
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            visible: keyboard && keyboard.layouts && keyboard.layouts.length > 1

            onClicked: {
                if (keyboard && keyboard.layouts && keyboard.layouts.length > 0)
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
            }
        }
    }

    // ─── Bottom-right: power controls ───
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 10

        IconButton {
            glyph: "\u23FB"   // power symbol
            tooltip: "Shut down"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            surfaceColor: config.surfaceColor
            borderColor: config.borderColor
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            visible: sddm.canPowerOff
            onClicked: sddm.powerOff()
        }

        IconButton {
            glyph: "\u21BB"   // circular arrow — restart
            tooltip: "Restart"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            surfaceColor: config.surfaceColor
            borderColor: config.borderColor
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            visible: sddm.canReboot
            onClicked: sddm.reboot()
        }

        IconButton {
            glyph: "\u263E"   // moon — suspend
            tooltip: "Suspend"
            fgColor: config.fgColor
            fgMuted: config.fgMuted
            surfaceColor: config.surfaceColor
            borderColor: config.borderColor
            accentColor: config.accentColor
            fontFamily: config.fontFamily
            visible: sddm.canSuspend
            onClicked: sddm.suspend()
        }
    }

    // ─── SDDM signals ───
    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.busy = false
            errorText.text = ""
        }

        function onLoginFailed() {
            root.busy = false
            errorText.text = "Authentication failed"
            passwordField.clearPassword()
            passwordField.forceFocus()
        }

        function onInformationMessage(message) {
            errorText.text = message
        }
    }

    function attemptLogin() {
        if (!root.selectedUserName) return
        root.busy = true
        errorText.text = ""
        sddm.login(root.selectedUserName, passwordField.text, root.selectedSessionIndex)
    }

    // ─── Keyboard navigation ───
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left && userRepeater.count > 1) {
            var next = root.selectedUserIndex - 1
            if (next < 0) next = userRepeater.count - 1
            root.selectedUserIndex = next
            passwordField.clearPassword()
            event.accepted = true
        } else if (event.key === Qt.Key_Right && userRepeater.count > 1) {
            var n = (root.selectedUserIndex + 1) % userRepeater.count
            root.selectedUserIndex = n
            passwordField.clearPassword()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            passwordField.clearPassword()
            passwordField.forceFocus()
            event.accepted = true
        }
    }

    Component.onCompleted: {
        passwordField.forceFocus()
    }
}
