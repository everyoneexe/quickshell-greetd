import QtQuick
import Quickshell

// Drop-in replacement for Quickshell.Services.Pam's PamContext, backed by
// greetd. Lets an existing lockscreen run as a greeter without touching its
// auth code: swap `import Quickshell.Services.Pam` for `import QsGreet` and
// `PamContext {}` for `GreetdPamContext {}`.
//
// Member set is exactly what a lockscreen uses:
//   config, configDirectory, active, start(), abort(), respond(),
//   responseRequired, pamMessage(), completed(result)
//
// Difference from real PAM: a lockscreen authenticates *itself*, a greeter
// authenticates *another user* and then launches their session. `user` says
// who is being logged in; it defaults to the configured target user.
QtObject {
    id: root

    // Accepted for source compatibility. greetd owns the PAM stack and
    // chooses the service, so these are inert.
    property string config: ""
    property string configDirectory: ""

    // Which account to authenticate.
    property string user: Users.selectedName

    // The secret to answer greetd's password prompt with. A lockscreen keeps
    // its own buffer (currentText) and hands it over via respond().
    property string secret: ""

    readonly property bool active: root._active
    readonly property bool responseRequired: root._responseRequired
    readonly property string message: Auth.promptMessage

    signal pamMessage
    signal completed(int result)

    property bool _active: false
    property bool _responseRequired: false
    property bool _awaitingSecret: false

    // A theme-side fingerprint context must not run: greetd owns the single
    // PAM conversation for the target user, and Greetd is a singleton, so a
    // second context would fight the password one for the session.
    //
    // This does not mean fingerprint login is impossible - it means the
    // greeter is the wrong place for it. Stack it where greetd already runs
    // PAM as root:
    //     # /etc/pam.d/greetd
    //     auth sufficient pam_fprintd.so
    // The reader prompts then arrive as ordinary greetd auth messages and
    // show up in Auth.infoMessage, with no privilege added to the greeter.
    readonly property bool supported: root.config !== "fprintd.conf"

    function start(): bool {
        if (!root.supported) {
            console.warn("QsGreet: fingerprint belongs in /etc/pam.d/greetd, not in the greeter; ignoring start()");
            return false;
        }
        if (root._active)
            return false;
        if (!Auth.available) {
            root.completed(PamResult.Error);
            return false;
        }

        root._active = true;

        if (root.secret.length > 0) {
            // Password already typed: hand it to the core, which answers
            // greetd's prompt without ever exposing respond() to the theme.
            Auth.login(root.user, root.secret);
        } else {
            // No secret yet: start the conversation and let greetd ask.
            root._awaitingSecret = true;
            Auth.login(root.user, "");
        }
        return true;
    }

    function abort(): void {
        if (!root._active)
            return;
        root._active = false;
        root._responseRequired = false;
        root._awaitingSecret = false;
        Auth.cancel();
    }

    function respond(response: string): void {
        if (!root._responseRequired)
            return;
        root._responseRequired = false;
        Auth.submitSecret(response);
    }

    readonly property Connections _authLink: Connections {
        target: Auth

        function onPromptRequested(message: string, echo: bool): void {
            if (!root._active)
                return;
            root._responseRequired = true;
            root.pamMessage();
        }

        function onFailed(message: string): void {
            if (!root._active)
                return;
            root._active = false;
            root._responseRequired = false;
            root._awaitingSecret = false;
            root.completed(PamResult.Failed);
        }

        function onLaunching(): void {
            if (!root._active)
                return;
            root._active = false;
            root._responseRequired = false;
            root.completed(PamResult.Success);
        }
    }
}
