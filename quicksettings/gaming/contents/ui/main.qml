// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick 2.15

import org.kde.kirigami as Kirigami

import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

QS.QuickSetting {
    id: root

    text: i18n("Gaming Mode")
    icon: "input-gamepad"
    status: enabled ? i18n("Active") : i18n("Inactive")
    enabled: ShellSettings.Settings.gamingModeEnabled

    function requestDisable() {
        confirmDisableDialog.active = true;
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
        onLoaded: item.open()

        sourceComponent: Kirigami.PromptDialog {
            id: theConfirmDialog
            title: i18n("Leave gaming mode?")
            subtitle: i18n("Your games will keep running in the background.")
            standardButtons: Kirigami.Dialog.NoButton
            customFooterActions: [
                Kirigami.Action {
                    text: i18n("Keep Playing")
                    onTriggered: theConfirmDialog.close()
                },
                Kirigami.Action {
                    text: i18n("Leave")
                    onTriggered: {
                        ShellSettings.Settings.gamingModeEnabled = false
                        theConfirmDialog.close()
                    }
                }
            ]
            onClosed: confirmDisableDialog.active = false
        }
    }
}
