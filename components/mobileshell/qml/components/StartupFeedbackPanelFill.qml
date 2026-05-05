// SPDX-FileCopyrightText: 2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

import QtQuick

import org.kde.plasma.private.mobileshell.state as MobileShellState

// Component to supplement the StartupFeedback window maximization animation for panel backgrounds.

Rectangle {
    id: root

    property real fullHeight
    property int screen
    property var maximizedTracker

    readonly property bool isShowing: height > 0

    // Smooth animation for colored rectangle
    NumberAnimation on height {
        id: heightAnim
        from: 0
        to: root.fullHeight
        duration: 200
        easing.type: Easing.OutExpo
    }

    // Auto-clear safety net.
    //
    // The colored fill is normally cleared by onShowingWindowChanged when
    // the launched app's maximized state toggles.  In convergence mode apps
    // launch centered (kwinrc Placement=Centered), so showingWindow may
    // never flip to true and the change-based cleanup never fires — the
    // band would otherwise remain on the panel indefinitely.
    //
    // This timer runs after every panel-fill animation and clears the
    // rectangle if no maximized/fullscreen window is present, restoring
    // the original mobile behaviour while fixing the convergence path.
    Timer {
        id: autoClearTimer
        interval: 600 // animation duration (200) + settle time
        repeat: false
        onTriggered: {
            if (!root.maximizedTracker || !root.maximizedTracker.showingWindow) {
                root.color = 'transparent';
                root.height = 0;
            }
        }
    }

    // Reset when maximized window state changes
    Connections {
        target: maximizedTracker

        function onShowingWindowChanged() {
            root.color = 'transparent';
            root.height = 0;
        }
    }

    // Listen to event from shell dbus
    Connections {
        target: MobileShellState.ShellDBusClient

        function onAppLaunchMaximizePanelAnimationTriggered(screen, color) {
            if (root.screen !== screen) {
                return;
            }

            root.color = color;
            heightAnim.restart();
            autoClearTimer.restart();
        }
    }
}
