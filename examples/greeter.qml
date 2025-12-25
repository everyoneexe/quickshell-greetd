import QtQuick
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    Greetd { id: greetd }

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "Login"
                color: "white"
                font.pixelSize: 24
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 280; height: 36
                color: "#313244"
                TextInput {
                    id: username
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "white"
                    onAccepted: password.focus = true
                }
            }

            Rectangle {
                width: 280; height: 36
                color: "#313244"
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 8
                    color: "white"
                    echoMode: TextInput.Password
                    onAccepted: greetd.login(username.text, password.text)
                }
            }
        }
    }
}
