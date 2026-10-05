import QtQuick
import Quickshell

// Bridge that lets an unmodified Quickshell *lockscreen surface* act as a
// greeter theme.
//
// Lockscreen surfaces are handed a "context" object by their host and talk to
// nothing else. This reproduces that object's shape on top of QsGreet.Auth,
// so a surface can be loaded verbatim.
//
// Shape matches illogical-impulse/inir's modules/lock/LockContext.qml, which
// is the de facto contract across Quickshell lockscreens:
//   currentText, unlockInProgress, showFailure, fingerprintsConfigured,
//   targetAction + ActionEnum, tryUnlock(), clearText(), resetClearTimer(),
//   resetTargetAction(), signals unlocked(action) / failed() / shouldReFocus()
QtObject {
    id: root

    enum ActionEnum {
        Unlock = 0,
        Poweroff = 1,
        Reboot = 2
    }

    property string currentText: ""
    property bool unlockInProgress: Auth.busy
    property bool showFailure: false

    // True when /etc/pam.d/greetd stacks pam_fprintd. The reader is driven by
    // greetd as root for the target user; the greeter only shows the
    // affordance and displays whatever the PAM stack says.
    readonly property bool fingerprintsConfigured: GreeterConfig.fingerprintEnabled

    // "Place your finger on the fingerprint reader" and friends.
    readonly property string statusMessage: Auth.infoMessage

    property int targetAction: GreeterLockContext.ActionEnum.Unlock
    property bool alsoInhibitIdle: false

    signal unlocked(var targetAction)
    signal failed
    signal shouldReFocus

    function resetTargetAction(): void {
        root.targetAction = GreeterLockContext.ActionEnum.Unlock;
    }

    function clearText(): void {
        root.currentText = "";
    }

    function resetClearTimer(): void {
        clearTimer.restart();
    }

    function reset(): void {
        root.resetTargetAction();
        root.clearText();
    }

    function tryUnlock(alsoInhibitIdle = false): void {
        root.alsoInhibitIdle = alsoInhibitIdle;

        if (root.targetAction === GreeterLockContext.ActionEnum.Poweroff) {
            Power.poweroff();
            return;
        }
        if (root.targetAction === GreeterLockContext.ActionEnum.Reboot) {
            Power.reboot();
            return;
        }

        if (Auth.promptActive) {
            Auth.submitSecret(root.currentText);
            root.clearText();
            return;
        }

        Auth.login(Users.selectedName, root.currentText);
    }

    onCurrentTextChanged: {
        if (root.currentText.length > 0)
            root.showFailure = false;
        clearTimer.restart();
    }

    readonly property Timer _clearTimer: Timer {
        id: clearTimer
        interval: 10000
        onTriggered: root.reset()
    }

    readonly property Connections _authLink: Connections {
        target: Auth

        function onFailed(message: string): void {
            root.currentText = "";
            root.showFailure = true;
            root.failed();
            root.shouldReFocus();
        }

        function onLaunching(): void {
            root.currentText = "";
            root.unlocked(root.targetAction);
        }
    }
}
