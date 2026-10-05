import QtQuick
import Quickshell
import Quickshell.Wayland

// Owns the window. Themes never create one, so "theme forgot to open a
// surface" - the failure mode that produced a silent black screen in the
// previous attempt - cannot happen.
//
// Window type is chosen by config because cage does not implement
// wlr-layer-shell (quickshell logs "Failed to initialize layershell
// integration" and ends up with a broken surface), while niri and sway do.
Scope {
    id: root

    // ShellScreen this host renders on; null in floating mode.
    property var targetScreen: null

    property string failureReason: ""
    readonly property bool failed: root.failureReason.length > 0

    function fail(reason: string): void {
        if (root.failed)
            return;
        console.warn(`QsGreet: falling back to built-in login: ${reason}`);
        root.failureReason = reason;
    }

    Loader {
        active: GreeterConfig.windowMode === "layer"
        sourceComponent: layerWindow
    }

    Loader {
        active: GreeterConfig.windowMode !== "layer"
        sourceComponent: floatingWindow
    }

    Component {
        id: layerWindow

        PanelWindow {
            screen: root.targetScreen
            color: "#0d1117"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Loader {
                anchors.fill: parent
                sourceComponent: surface
            }
        }
    }

    Component {
        id: floatingWindow

        FloatingWindow {
            color: "#0d1117"

            Loader {
                anchors.fill: parent
                sourceComponent: surface
            }
        }
    }

    Component {
        id: surface

        FocusScope {
            id: surfaceRoot
            focus: true

            Component.onCompleted: {
                if (GreeterConfig.themeMain.length === 0)
                    root.fail("no theme configured");
            }

            Loader {
                id: themeLoader
                anchors.fill: parent
                focus: !root.failed
                active: !root.failed && GreeterConfig.themeMain.length > 0
                source: GreeterConfig.themeMain

                onStatusChanged: {
                    if (status === Loader.Error)
                        root.fail(`theme '${GreeterConfig.theme}' failed to load`);
                    else if (status === Loader.Ready)
                        watchdog.restart();
                }

                onLoaded: {
                    if (item && item.forceActiveFocus)
                        item.forceActiveFocus();
                }
            }

            // Themes report their own internal failures here; a theme that
            // loads but cannot build its surface still gets recovered.
            Connections {
                target: themeLoader.item
                ignoreUnknownSignals: true
                function onThemeErrorChanged(): void {
                    const message = themeLoader.item.themeError;
                    if (message && message.length > 0)
                        root.fail(message);
                }
            }

            Loader {
                anchors.fill: parent
                active: root.failed
                focus: root.failed
                sourceComponent: FallbackLogin {
                    reason: root.failureReason
                }
            }

            // A theme that loads but never produces geometry is as broken as
            // one that throws. Catch it and recover instead of showing void.
            Timer {
                id: watchdog
                interval: Math.max(1, GreeterConfig.themeWatchdogSeconds) * 1000
                running: GreeterConfig.themeWatchdogSeconds > 0 && !root.failed
                repeat: false
                onTriggered: {
                    const item = themeLoader.item;
                    if (!item)
                        root.fail("theme produced no item");
                    else if (item.width <= 0 || item.height <= 0)
                        root.fail("theme drew nothing");
                }
            }
        }
    }
}
