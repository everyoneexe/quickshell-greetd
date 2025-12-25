import QtQuick
import Quickshell
import Quickshell.Services.Greetd

ShellRoot {
    property string username: ""
    property string password: ""

    // Greetd integration
    Connections {
        target: Greetd
        
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                if (message.toLowerCase().includes("password")) {
                    Greetd.respond(password)
                } else {
                    Greetd.respond(username)
                }
            }
        }
        
        function onAuthFailure(message) {
            passwordField.text = ""
            username = ""
            password = ""
        }
        
        function onReadyToLaunch() {
            // Launch default session (Hyprland)
            Greetd.launch(["/usr/bin/Hyprland"])
        }
    }

    // ii-style greeter UI
    Rectangle {
        anchors.fill: parent
        color: "#0d1117"
        
        // Background gradient
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0d1117" }
                GradientStop { position: 1.0; color: "#161b22" }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 24

            // ii logo/title
            Text {
                text: "ii"
                color: "#58a6ff"
                font.pixelSize: 64
                font.weight: Font.Light
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Welcome back"
                color: "#f0f6fc"
                font.pixelSize: 18
                opacity: 0.8
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Username field
            Rectangle {
                width: 320
                height: 48
                color: "#21262d"
                border.color: usernameField.focus ? "#58a6ff" : "#30363d"
                border.width: 1
                radius: 6

                TextInput {
                    id: usernameField
                    anchors.fill: parent
                    anchors.margins: 16
                    color: "#f0f6fc"
                    font.pixelSize: 16
                    selectByMouse: true
                    
                    Text {
                        anchors.fill: parent
                        text: "Username"
                        color: "#7d8590"
                        font.pixelSize: 16
                        visible: parent.text.length === 0
                    }
                    
                    onAccepted: passwordField.focus = true
                    onTextChanged: username = text
                }
            }

            // Password field
            Rectangle {
                width: 320
                height: 48
                color: "#21262d"
                border.color: passwordField.focus ? "#58a6ff" : "#30363d"
                border.width: 1
                radius: 6

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 16
                    color: "#f0f6fc"
                    font.pixelSize: 16
                    echoMode: TextInput.Password
                    selectByMouse: true
                    
                    Text {
                        anchors.fill: parent
                        text: "Password"
                        color: "#7d8590"
                        font.pixelSize: 16
                        visible: parent.text.length === 0
                    }
                    
                    onAccepted: {
                        if (username && text) {
                            password = text
                            Greetd.createSession(username)
                        }
                    }
                    onTextChanged: password = text
                }
            }

            // Login button
            Rectangle {
                width: 320
                height: 40
                color: loginMouse.pressed ? "#1f6feb" : "#238636"
                radius: 6
                
                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    onClicked: {
                        if (username && password) {
                            Greetd.createSession(username)
                        }
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "Sign in"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }
            }
        }

        // Status indicator
        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 16
            text: Greetd.available ? "greetd ready" : "greetd unavailable"
            color: Greetd.available ? "#238636" : "#da3633"
            font.pixelSize: 12
            opacity: 0.7
        }
    }
}
