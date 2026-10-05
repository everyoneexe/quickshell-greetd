pragma Singleton

import Quickshell

// Entries look like:
//   { "name": "fukushima", "displayName": "Fukushima", "uid": 1000,
//     "home": "/home/fukushima", "avatar": "/var/lib/AccountsService/icons/fukushima" }
// Produced by the launcher from getent + /etc/login.defs UID_MIN/UID_MAX.
Singleton {
    id: root

    readonly property var list: GreeterConfig.envJson("QSGREET_USERS_JSON", [])
    readonly property int count: root.list.length

    property string selectedName: GreeterConfig.user.length > 0 ? GreeterConfig.user : (root.count > 0 ? root.list[0].name : "")

    readonly property var selected: root.find(root.selectedName)

    // Themes copied from a lockscreen render the *logged-in* user's identity.
    // These are what a greeter must substitute for SystemInfo.username and
    // friends, otherwise the screen literally says "greeter".
    readonly property string displayName: {
        const user = root.selected;
        if (!user)
            return root.selectedName;
        return user.displayName && user.displayName.length > 0 ? user.displayName : user.name;
    }

    readonly property string avatar: root.selected && root.selected.avatar ? root.selected.avatar : ""
    readonly property string home: root.selected && root.selected.home ? root.selected.home : ""

    function find(name: string): var {
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i].name === name)
                return root.list[i];
        }
        return null;
    }

    function select(name: string): void {
        if (!GreeterConfig.lockUser)
            root.selectedName = name;
    }

    function cycle(): void {
        if (GreeterConfig.lockUser || root.count < 2)
            return;
        let index = 0;
        for (let i = 0; i < root.count; i++) {
            if (root.list[i].name === root.selectedName) {
                index = i;
                break;
            }
        }
        root.selectedName = root.list[(index + 1) % root.count].name;
    }
}
