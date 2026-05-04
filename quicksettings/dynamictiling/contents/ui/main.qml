// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick

import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

QS.QuickSetting {
    text: i18n("Dynamic Tiling")
    icon: "view-grid-symbolic"

    // Only meaningful in convergence (desktop) mode.  Hidden everywhere else.
    available: ShellSettings.Settings.convergenceModeEnabled
            && !ShellSettings.Settings.gamingModeEnabled

    enabled: ShellSettings.Settings.dynamicTilingEnabled
    status: enabled ? i18n("On") : i18n("Off")

    function toggle() {
        ShellSettings.Settings.dynamicTilingEnabled = !ShellSettings.Settings.dynamicTilingEnabled;
    }
}
