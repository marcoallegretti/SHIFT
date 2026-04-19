// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick 2.15

import org.kde.kirigami as Kirigami

import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

QS.QuickSetting {
    id: root

    text: i18n("Gaming Mode")
    icon: "input-gaming"
    status: enabled ? i18n("Active") : i18n("Inactive")
    enabled: ShellSettings.Settings.gamingModeEnabled

    function requestDisable() {
        confirmDisableDialog.active = true;
        confirmDisableDialog.item.open();
    }

    function toggle() {
        if (ShellSettings.Settings.gamingModeEnabled) {
            requestDisable();
            return;
        }

        ShellSettings.Settings.gamingModeEnabled = true;
    }

    Loader {
        id: confirmDisableDialog
        active: false

        sourceComponent: Kirigami.PromptDialog {
            title: i18n("Exit Gaming Mode")
            subtitle: i18n("Switch back to the normal shell layout?")
            standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.Cancel

            onAccepted: ShellSettings.Settings.gamingModeEnabled = false
            onClosed: confirmDisableDialog.active = false
        }
    }
}
