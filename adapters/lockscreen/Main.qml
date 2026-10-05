// Lockscreen adapter.
//
// Installed into a theme's shell tree as _qsgreet-main.qml by
// qsgreet-theme-prepare. Loads an existing lock surface verbatim and feeds
// it a greetd-backed context instead of the lockscreen's PAM-backed one.
//
// QSGREET_SURFACE selects the surface, relative to the shell tree:
//   modules/iris/lock/IrisLockSurface.qml
//   modules/lock/LockSurface.qml
//   modules/waffle/lock/WaffleLockSurfaceSafe.qml
//
// QSGREET_CONTEXT, when set, is the shell's own context file that prepare
// substituted. Surfaces that declare `required property LockContext context`
// reject any other type, so the context has to be created from that exact
// file. Surfaces using `property var context` get GreeterLockContext.

import QtQuick
import QsGreet

Item {
    id: root

    anchors.fill: parent

    // Theme contract: a non-empty themeError makes the core swap in its
    // built-in login instead of leaving a dead screen on the display.
    property string themeError: ""

    readonly property string surface: GreeterConfig.envOr("QSGREET_SURFACE", "")
    readonly property string contextFile: GreeterConfig.envOr("QSGREET_CONTEXT", "")
    readonly property string contextImport: GreeterConfig.envOr("QSGREET_CONTEXT_IMPORT", "")
    readonly property string contextType: GreeterConfig.envOr("QSGREET_CONTEXT_TYPE", "")

    property var lockContext: null

    GreeterLockContext {
        id: builtinContext
    }

    Component.onCompleted: {
        if (root.surface.length === 0) {
            root.themeError = "QSGREET_SURFACE is not set";
            return;
        }

        root.lockContext = builtinContext;

        // QML gives a file loaded by URL a different type identity from the
        // same file registered in a qmldir. A surface that does
        // `import qs.modules.lock` will reject the URL-loaded one with
        // "Cannot assign QObject* to LockContext_QMLTYPE_*", so when the
        // context is module-registered it has to be created that way.
        if (root.contextImport.length > 0 && root.contextType.length > 0) {
            try {
                root.lockContext = Qt.createQmlObject(
                    `import ${root.contextImport}\n${root.contextType} {}`,
                    root
                );
            } catch (error) {
                root.themeError = `context ${root.contextImport}.${root.contextType}: ${error}`;
                return;
            }
        } else if (root.contextFile.length > 0) {
            const component = Qt.createComponent(Qt.resolvedUrl(root.contextFile));
            if (component.status === Component.Error) {
                root.themeError = `context '${root.contextFile}': ${component.errorString()}`;
                return;
            }
            const instance = component.createObject(root);
            if (!instance) {
                root.themeError = `context '${root.contextFile}' could not be created`;
                return;
            }
            root.lockContext = instance;
        }

        surfaceLoader.setSource(Qt.resolvedUrl(root.surface), {
            context: root.lockContext
        });
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        asynchronous: false

        onStatusChanged: {
            if (status === Loader.Error)
                root.themeError = `surface '${root.surface}' failed to load`;
        }

        onLoaded: {
            if (item && item.forceActiveFocus)
                item.forceActiveFocus();
        }
    }

    // Loader.status does not go to Error when the component builds but a
    // required property is rejected - the item simply never appears, and the
    // screen stays black with only a warning on stderr. Measured with an
    // end-4 lockscreen whose typed LockContext refused a foreign object.
    // Catch that here rather than relying on the core's watchdog, which sees
    // this Item as perfectly healthy.
    Timer {
        running: root.themeError.length === 0
        interval: 1500
        onTriggered: {
            if (!surfaceLoader.item)
                root.themeError = `surface '${root.surface}' produced no item`;
        }
    }

    Connections {
        target: root.lockContext

        function onShouldReFocus(): void {
            if (surfaceLoader.item && surfaceLoader.item.forceActiveFocus)
                surfaceLoader.item.forceActiveFocus();
        }
    }
}
