//@ pragma UseQApplication

// Greeter entry point.
//
// qsgreet-theme-prepare copies this file into the theme's shell tree as
// _qsgreet-entry.qml, so Quickshell's shell root IS that tree. That is the
// only arrangement in which a shell's own `import qs.*` and `root:` imports
// resolve, which is what makes an untouched lockscreen render identically
// here and on the desktop.
//
// QsGreet itself comes from QML_IMPORT_PATH and is independent of the theme.

import QtQuick
import Quickshell
import QsGreet

ShellRoot {
    // One host per screen where wlr-layer-shell exists (niri, sway).
    Loader {
        active: GreeterConfig.windowMode === "layer"

        sourceComponent: Variants {
            model: Quickshell.screens

            ThemeHost {
                required property var modelData
                targetScreen: modelData
            }
        }
    }

    // cage has no layer shell; it is single-output and fullscreens its only
    // client, so one plain toplevel is both correct and sufficient.
    Loader {
        active: GreeterConfig.windowMode !== "layer"
        sourceComponent: ThemeHost {}
    }
}
