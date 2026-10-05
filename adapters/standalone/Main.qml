// Standalone adapter.
//
// For surfaces that are already complete greeters rather than lockscreens:
// they hold their own state and expect no host-supplied context. Airlock's
// modules/GreeterSurface.qml is the reference case.
//
// The core still owns the window and the recovery path, so a surface that
// fails to load or draw is replaced by the built-in login exactly as a
// lockscreen theme would be.
//
// Note what this adapter does NOT give you: a surface like this usually
// talks to Quickshell.Services.Greetd directly, so QsGreet.Auth is bypassed
// and the "themes cannot drive authentication" guarantee does not hold for
// it. Prefer the lockscreen adapter, or a theme written against QsGreet.

import QtQuick
import QsGreet

Item {
    id: root

    anchors.fill: parent

    property string themeError: ""

    readonly property string surface: GreeterConfig.envOr("QSGREET_SURFACE", "shell.qml")

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        asynchronous: false
        source: Qt.resolvedUrl(root.surface)

        onStatusChanged: {
            if (status === Loader.Error)
                root.themeError = `surface '${root.surface}' failed to load`;
        }

        onLoaded: {
            if (item && item.forceActiveFocus)
                item.forceActiveFocus();
        }
    }
}
