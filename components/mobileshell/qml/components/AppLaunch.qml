// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick

import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

// NOTE: This is a singleton in the mobileshell library, so we need to be careful to
// make this load as fast as possible (since it may be loaded in other processes ex. lockscreen).

pragma Singleton

QtObject {
    id: root

    /**
     * Activates an application by storage id if it is already running, or launch the application.
     */
    function launchOrActivateApp(storageId) {
        const skipActivate = ShellSettings.Settings.convergenceModeEnabled;

        // We don't want to import WindowPlugin initially because it has side-effects and slows down initial load.
        // -> only import it if we actually run the function
        const component = Qt.createQmlObject(`
            import QtQuick
            import org.kde.plasma.private.mobileshell as MobileShell
            import org.kde.plasma.private.mobileshell.windowplugin as WindowPlugin

            QtObject {
                Component.onCompleted: {
                    if (!${skipActivate}) {
                        const launched = WindowPlugin.WindowUtil.activateWindowByStorageId("${storageId}");
                        if (launched) return;
                    }
                    MobileShell.ShellUtil.launchApp("${storageId}");
                }
            }
        `, root, "runSnippet");

        component.destroy();
    }
}
