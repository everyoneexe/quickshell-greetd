import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Built-in, dependency-free login. Shown when the configured theme fails to
// load or fails to draw. This is the thing SDDM does not have: a broken theme
// there means a black screen and a TTY rescue.
FocusScope {
    id: root

    required property string reason

    focus: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#0d1117"
            }
            GradientStop {
                position: 1.0
                color: "#161b22"
            }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14
        width: 360

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.now, "HH:mm")
            color: "#f0f6fc"
            font.pixelSize: 56
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.now, "dddd, d MMMM")
            color: "#8b949e"
            font.pixelSize: 14
        }

        Item {
            Layout.preferredHeight: 12
        }

        TextField {
            id: userField
            Layout.fillWidth: true
            placeholderText: "Username"
            text: Users.selectedName
            readOnly: GreeterConfig.lockUser
            visible: !GreeterConfig.lockUser
            enabled: !Auth.busy
            onAccepted: passField.forceActiveFocus()
        }

        TextField {
            id: passField
            Layout.fillWidth: true
            placeholderText: Auth.promptActive ? Auth.promptMessage : "Password"
            echoMode: Auth.promptActive && Auth.promptEcho ? TextInput.Normal : TextInput.Password
            enabled: !Auth.busy
            focus: true
            onAccepted: root.submit()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: Sessions.selectedName.length > 0 ? Sessions.selectedName : "Session"
                enabled: Sessions.count > 1 && !Auth.busy
                visible: Sessions.count > 0
                onClicked: Sessions.cycle()
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: Auth.busy ? "…" : "Sign in"
                enabled: !Auth.busy
                onClicked: root.submit()
            }
        }

        // Reader prompts and other PAM chatter, e.g. from pam_fprintd.
        Text {
            Layout.fillWidth: true
            text: Auth.infoMessage
            visible: Auth.infoMessage.length > 0
            color: "#58a6ff"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: Auth.errorText
            visible: Auth.errorText.length > 0
            color: "#f85149"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            text: `fallback login — ${root.reason}`
            color: "#6e7681"
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            visible: Power.enabled

            Button {
                text: "Power off"
                onClicked: Power.poweroff()
            }

            Button {
                text: "Reboot"
                onClicked: Power.reboot()
            }
        }
    }

    function submit(): void {
        if (Auth.promptActive) {
            Auth.submitSecret(passField.text);
            passField.text = "";
            return;
        }
        const user = GreeterConfig.lockUser ? Users.selectedName : userField.text;
        Auth.login(user, passField.text);
        passField.text = "";
    }

    QtObject {
        id: clock
        property date now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    Component.onCompleted: passField.forceActiveFocus()
}
