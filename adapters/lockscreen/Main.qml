// Lockscreen adapter.
//
// Installed into a theme's shell tree as _qsgreet-main.qml by
// qsgreet-theme-prepare. Loads an existing lock surface verbatim - no edits,
// no copies - and feeds it a GreeterLockContext instead of the lockscreen's
// PAM-backed LockContext.
//
// QSGREET_SURFACE selects the surface, relative to the shell tree:
//   modules/iris/lock/IrisLockSurface.qml
//   modules/lock/LockSurface.qml
//   modules/waffle/lock/WaffleLockSurfaceSafe.qml

import QtQuick
import QsGreet

Item {
    id: root

    anchors.fill: parent

    // Theme contract: a non-empty themeError makes the core swap in its
    // built-in login instead of leaving a dead screen on the display.
    property string themeError: ""

    readonly property string surface: GreeterConfig.envOr("QSGREET_SURFACE", "modules/iris/lock/IrisLockSurface.qml")

    GreeterLockContext {
        id: lockContext
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        asynchronous: false

        Component.onCompleted: setSource(Qt.resolvedUrl(root.surface), {
            context: lockContext
        })

        onStatusChanged: {
            if (status === Loader.Error)
                root.themeError = `lock surface '${root.surface}' failed to load`;
        }

        onLoaded: {
            if (item && item.forceActiveFocus)
                item.forceActiveFocus();
        }
    }

    Connections {
        target: lockContext

        function onShouldReFocus(): void {
            if (surfaceLoader.item && surfaceLoader.item.forceActiveFocus)
                surfaceLoader.item.forceActiveFocus();
        }
    }
}
