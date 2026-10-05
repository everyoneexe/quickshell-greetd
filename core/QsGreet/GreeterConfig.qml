pragma Singleton

import Quickshell

// Every value is projected into the environment by quickshell-greetd-launcher,
// which is the single source of truth (see /etc/quickshell-greetd/config.env).
// Nothing here touches the filesystem, so the greeter cannot fail to start
// because of a malformed or unreadable config file.
Singleton {
    id: root

    function envOr(name: string, fallback: string): string {
        const value = Quickshell.env(name);
        if (value === undefined || value === null)
            return fallback;
        const text = String(value).trim();
        return text.length > 0 ? text : fallback;
    }

    function envJson(name: string, fallback: var): var {
        const raw = root.envOr(name, "");
        if (raw.length === 0)
            return fallback;
        try {
            return JSON.parse(raw);
        } catch (e) {
            console.warn(`QsGreet: ${name} is not valid JSON, ignoring:`, e);
            return fallback;
        }
    }

    // Theme directory name under themeRoot, e.g. "iris". A theme is a
    // prepared Quickshell shell tree; qsgreet-theme-prepare injects the
    // adapter as shell/_qsgreet-main.qml. "fallback" means no theme at all,
    // which leaves the core's built-in login on screen.
    readonly property string theme: root.envOr("QSGREET_THEME", "fallback")
    readonly property string themeRoot: root.envOr("QSGREET_THEME_ROOT", "/usr/share/quickshell-greetd/themes")
    readonly property string themeMain: root.theme === "fallback" ? "" : `${root.themeRoot}/${root.theme}/shell/_qsgreet-main.qml`

    // Target login user. Empty means the theme must ask for one.
    readonly property string user: root.envOr("QSGREET_USER", "")
    readonly property bool lockUser: root.user.length > 0 && root.envOr("QSGREET_LOCK_USER", "1") !== "0"

    // "floating" for cage (no wlr-layer-shell), "layer" for niri/sway.
    readonly property string windowMode: root.envOr("QSGREET_WINDOW_MODE", "floating")

    // Seconds the theme has to put something on screen before the core
    // replaces it with the built-in login. 0 disables the watchdog.
    readonly property int themeWatchdogSeconds: parseInt(root.envOr("QSGREET_THEME_WATCHDOG", "6"), 10)

    readonly property bool powerEnabled: root.envOr("QSGREET_POWER_ENABLED", "1") !== "0"

    // Set by the launcher when /etc/pam.d/greetd stacks pam_fprintd. The
    // greeter never talks to fprintd itself; greetd drives that conversation
    // as root for the target user. This only tells themes to offer the
    // affordance.
    readonly property bool fingerprintEnabled: root.envOr("QSGREET_FINGERPRINT", "0") === "1"
}
