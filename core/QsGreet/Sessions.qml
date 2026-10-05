pragma Singleton

import Quickshell

// Desktop-file discovery is done once, in the launcher, and handed over as
// JSON. Entries look like:
//   { "id": "niri", "name": "Niri", "exec": ["niri-session"], "type": "wayland" }
Singleton {
    id: root

    readonly property var list: GreeterConfig.envJson("QSGREET_SESSIONS_JSON", [])
    readonly property int count: root.list.length

    property int selectedIndex: root.indexOfId(GreeterConfig.envOr("QSGREET_LAST_SESSION", ""))

    readonly property var selected: root.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.count ? root.list[root.selectedIndex] : null

    readonly property string selectedName: root.selected ? root.selected.name : ""

    // Command handed to greetd. Falls back to the configured default so a
    // theme that never touches session selection still logs in.
    readonly property var command: {
        if (root.selected && root.selected.exec && root.selected.exec.length > 0)
            return root.selected.exec;
        return GreeterConfig.envJson("QSGREET_DEFAULT_COMMAND", []);
    }

    readonly property var env: GreeterConfig.envJson("QSGREET_SESSION_ENV", [])

    function indexOfId(id: string): int {
        if (id.length === 0)
            return root.list.length > 0 ? 0 : -1;
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i].id === id)
                return i;
        }
        return root.list.length > 0 ? 0 : -1;
    }

    function select(id: string): void {
        const index = root.indexOfId(id);
        if (index >= 0)
            root.selectedIndex = index;
    }

    function cycle(): void {
        if (root.count > 1)
            root.selectedIndex = (root.selectedIndex + 1) % root.count;
    }
}
