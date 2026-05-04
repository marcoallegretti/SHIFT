// SPDX-FileCopyrightText: 2023 Plata Hill <plata.hill@kdemail.net>
// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import org.kde.kwin as KWinComponents
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

Loader {
    id: root

    property var currentWindow

    // Windows awaiting geometry clamping after un-maximize in convergence
    // mode.  Using an array so concurrent un-maximizes are not lost.
    property var pendingConstrainWindows: []

    // After a window is un-maximized in convergence mode, the dockSpaceReserver
    // LayerShell surface needs one Wayland roundtrip to (re)commit its exclusive
    // zone so that KWin updates MaximizeArea.  We wait 200 ms — well within the
    // dock slide-in animation — then clamp the window bottom to MaximizeArea so
    // it cannot overlap the dock.
    Timer {
        id: constrainAfterRestoreTimer
        interval: 200
        onTriggered: {
            const windows = root.pendingConstrainWindows.slice()
            root.pendingConstrainWindows = []
            for (const window of windows) {
                if (!window || window.deleted || !window.normalWindow) continue
                if (!ShellSettings.Settings.convergenceModeEnabled) continue
                if (ShellSettings.Settings.gamingModeEnabled) continue

                const output = window.output
                const desktop = window.desktops[0]
                if (!output) continue
                if (!desktop) continue

                const maxRect = KWinComponents.Workspace.clientArea(
                    KWinComponents.Workspace.MaximizeArea, output, desktop)
                const geo = window.frameGeometry
                const maxBottom = maxRect.y + maxRect.height

                if (geo.y + geo.height > maxBottom) {
                    // Clip the bottom edge to MaximizeArea; preserve top position
                    // and width.  Ensure height is at least 100px to avoid
                    // pathological cases where the window starts above maxRect.
                    const newH = Math.max(100, maxBottom - geo.y)
                    window.frameGeometry = Qt.rect(geo.x, geo.y, geo.width, newH)
                }
            }
        }
    }

    function run(window) {
        if (!window || window.deleted || !window.normalWindow) {
            return;
        }

        // HACK: don't maximize xwaylandvideobridge
        // see: https://invent.kde.org/plasma/plasma-mobile/-/issues/324
        if (window.resourceClass === 'xwaylandvideobridge') {
            return;
        }

        if (ShellSettings.Settings.gamingModeEnabled) {
            window.noBorder = true;
            window.setMaximize(true, true);
            return;
        }

        if (ShellSettings.Settings.convergenceModeEnabled) {
            window.noBorder = false;
        } else {
            if (!window.fullScreen) {
                const output = window.output;
                const desktop = window.desktops[0]; // assume it's the first desktop that the window is on
                if (desktop === undefined) {
                    return;
                }
                const maximizeRect = KWinComponents.Workspace.clientArea(KWinComponents.Workspace.MaximizeArea, output, desktop);

                // set the window to the maximized size and position instantly, avoiding race condition
                // between maximizing and window decorations being turned off (changing window height)
                // see: https://invent.kde.org/teams/plasma-mobile/issues/-/issues/256
                window.frameGeometry = maximizeRect;
            }

            // turn off window decorations
            window.noBorder = true;

            if (!window.fullScreen) {
                // run maximize after to ensure the state is maximized
                window.setMaximize(true, true);
            }
        }
    }

    Connections {
        target: currentWindow

        function onFullScreenChanged() {
            if (!currentWindow) {
                return;
            }
            currentWindow.interactiveMoveResizeFinished.connect((currentWindow) => {
                root.run(currentWindow);
            });
            root.run(currentWindow);
        }

        function onMaximizedChanged() {
            if (!currentWindow) {
                return;
            }
            if (!currentWindow.maximizable) {
                return;
            }
            currentWindow.interactiveMoveResizeFinished.connect((currentWindow) => {
                root.run(currentWindow);
            });
            root.run(currentWindow);
            // Schedule a deferred geometry clamp so that the restored window
            // doesn't overlap the dock after the dockSpaceReserver exclusive
            // zone is re-committed over a Wayland roundtrip.
            if (ShellSettings.Settings.convergenceModeEnabled
                    && ShellSettings.Settings.autoHidePanelsEnabled) {
                root.pendingConstrainWindows.push(currentWindow)
                constrainAfterRestoreTimer.restart()
            }
        }
    }

    Connections {
        target: ShellSettings.Settings

        function onConvergenceModeEnabledChanged() {
            const windows = KWinComponents.Workspace.windows;

            for (let i = 0; i < windows.length; i++) {
                if (windows[i].normalWindow) {
                    root.run(windows[i]);
                }
            }
        }

        function onGamingModeEnabledChanged() {
            const windows = KWinComponents.Workspace.windows;

            for (let i = 0; i < windows.length; i++) {
                if (windows[i].normalWindow) {
                    root.run(windows[i]);
                }
            }
        }
    }

    Connections {
        target: KWinComponents.Workspace

        function onWindowAdded(window) {
            if (!window) {
                return;
            }
            if (window.normalWindow) {
                window.interactiveMoveResizeFinished.connect((window) => {
                    root.run(window);
                });
                root.run(window);
            }
        }

        function onWindowActivated(window) {
            if (!window) {
                return;
            }
            if (window.normalWindow) {
                currentWindow = window;
                window.interactiveMoveResizeFinished.connect((window) => {
                    root.run(window);
                });
                root.run(window);
            }
        }

        function onScreensChanged() {
            // Windows are moved from the external screen
            // to the internal screen if the external screen
            // is disconnected.
            const windows = KWinComponents.Workspace.windows;

            for (var i = 0; i < windows.length; i++) {
                if (windows[i].normalWindow) {
                    root.run(windows[i]);
                }
            }
        }
    }
}
