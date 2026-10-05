pragma Singleton

import Quickshell

// Power actions live in the core, not in themes: a theme asks, the core
// decides whether it is allowed and which binary runs.
Singleton {
    id: root

    readonly property bool enabled: GreeterConfig.powerEnabled

    function poweroff(): void {
        root._run("poweroff");
    }

    function reboot(): void {
        root._run("reboot");
    }

    function suspend(): void {
        root._run("suspend");
    }

    function _run(action: string): void {
        if (!root.enabled) {
            console.warn(`QsGreet: power action '${action}' is disabled by config`);
            return;
        }
        Quickshell.execDetached(["systemctl", action]);
    }
}
