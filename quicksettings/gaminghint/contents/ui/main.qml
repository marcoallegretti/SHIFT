// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick 2.15

import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

QS.QuickSetting {
    text: i18n("Game Center Hint")
    icon: "dialog-information"
    status: ""
    enabled: ShellSettings.Settings.gamingDismissHintEnabled

    function toggle() {
        ShellSettings.Settings.gamingDismissHintEnabled = !ShellSettings.Settings.gamingDismissHintEnabled;
    }
}
