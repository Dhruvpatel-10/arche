import QtQuick 2.15

Column {
    id: root

    property color textColor: "#3a3d48"
    property string fontFamily: "MesloLGS Nerd Font Mono"

    spacing: 2

    property var lines: [
        "[ OK ] Started Hostname Service.",
        "[ OK ] Reached target Sound Card.",
        "[ OK ] Started D-Bus System Message Bus.",
        "[ OK ] Reached target System Initialization.",
        "[ OK ] Started Login Service.",
        "[ OK ] Reached target Basic System.",
        "[ OK ] Started NetworkManager.",
        "[ OK ] Reached target Network.",
        "[ OK ] Started Authorization Manager.",
        "[ OK ] Started Modem Manager.",
        "[ OK ] Started OpenSSH Daemon.",
        "[ OK ] Started Bluetooth Service.",
        "[ OK ] Reached target Login Prompts.",
        "[ OK ] Started TLP system startup.",
        "[ OK ] Reached target Multi-User System.",
        "[ OK ] Reached target Graphical Interface."
    ]

    Repeater {
        model: root.lines
        delegate: Text {
            text: modelData
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 11
            opacity: Math.max(0, 0.45 - (index * 0.025))
        }
    }
}
