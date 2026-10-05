pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Greetd

// The only object in the greeter that touches greetd.
//
// Themes call login()/submitSecret() and read state/errorText. They never see
// Greetd.respond() and never drive the protocol, so a broken theme cannot
// wedge the authentication state machine - it can only fail to draw, which
// ThemeHost detects and recovers from.
Singleton {
    id: root

    // "idle" | "authenticating" | "prompt" | "launching" | "failed"
    readonly property string state: root._state
    readonly property bool busy: root._state === "authenticating" || root._state === "launching"
    readonly property string errorText: root._errorText
    readonly property string username: root._username
    readonly property bool available: Greetd.available

    // Set while greetd asks something the core has no stored answer for.
    readonly property bool promptActive: root._state === "prompt"
    readonly property string promptMessage: root._promptMessage
    readonly property bool promptEcho: root._promptEcho

    // Informational text from the PAM stack that needs no answer, such as
    // pam_fprintd's "Place your finger on the fingerprint reader". greetd
    // runs that conversation as root for the target user, so a theme can
    // display these without the greeter gaining any privilege.
    readonly property string infoMessage: root._infoMessage

    signal failed(string message)
    signal promptRequested(string message, bool echo)
    signal info(string message, bool error)
    signal launching

    property string _state: "idle"
    property string _errorText: ""
    property string _infoMessage: ""
    property string _username: ""
    property string _promptMessage: ""
    property bool _promptEcho: true
    property string _pendingSecret: ""
    property bool _hasPendingSecret: false

    function login(user: string, secret: string): void {
        if (!Greetd.available) {
            root._fail("greetd is not available (GREETD_SOCK unset)");
            return;
        }
        if (user.length === 0) {
            root._fail("no user selected");
            return;
        }
        if (root.busy)
            return;

        root._username = user;
        root._errorText = "";
        root._infoMessage = "";
        root._pendingSecret = secret;
        // An empty secret is not an answer. Starting with none is how a
        // fingerprint-first stack works: greetd asks, the reader answers,
        // and the password prompt only appears if that fails.
        root._hasPendingSecret = secret.length > 0;
        root._state = "authenticating";
        Greetd.createSession(user);
    }

    // Answer a prompt the core could not answer from the stored secret
    // (second factor, password change, security questions).
    function submitSecret(secret: string): void {
        if (root._state !== "prompt")
            return;
        root._state = "authenticating";
        root._promptMessage = "";
        Greetd.respond(secret);
    }

    function cancel(): void {
        root._clearSecret();
        if (root._state !== "idle") {
            Greetd.cancelSession();
            root._state = "idle";
        }
    }

    function _clearSecret(): void {
        root._pendingSecret = "";
        root._hasPendingSecret = false;
    }

    function _fail(message: string): void {
        root._clearSecret();
        root._errorText = message;
        root._promptMessage = "";
        root._infoMessage = "";
        root._state = "failed";
        root.failed(message);
    }

    Connections {
        target: Greetd

        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (!responseRequired) {
                // Needs no answer; Quickshell acks greetd itself. This is how
                // pam_fprintd reader prompts arrive when /etc/pam.d/greetd
                // stacks it, so hand the text to the theme rather than
                // dropping it.
                if (error)
                    root._errorText = message;
                else
                    root._infoMessage = message;
                root.info(message, error);
                return;
            }

            if (root._hasPendingSecret) {
                const secret = root._pendingSecret;
                root._clearSecret();
                Greetd.respond(secret);
                return;
            }

            root._promptMessage = message;
            root._promptEcho = echoResponse;
            root._state = "prompt";
            root.promptRequested(message, echoResponse);
        }

        function onAuthFailure(message: string): void {
            root._fail(message.length > 0 ? message : "authentication failed");
        }

        function onError(message: string): void {
            root._fail(message.length > 0 ? message : "greetd error");
        }

        function onReadyToLaunch(): void {
            root._clearSecret();

            const command = Sessions.command;
            if (!command || command.length === 0) {
                root._fail("no session command configured");
                Greetd.cancelSession();
                return;
            }

            root._state = "launching";
            root.launching();
            // quit=true: greetd expects the greeter to exit immediately.
            Greetd.launch(command, Sessions.env, true);
        }
    }
}
