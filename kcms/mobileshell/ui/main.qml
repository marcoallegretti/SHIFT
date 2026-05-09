/*
 * SPDX-FileCopyrightText: 2022 Devin Lin <devin@kde.org>
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kirigamiaddons.formcard 1.0 as FormCard
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

KCM.SimpleKCM {
    id: root

    title: i18n("Shell")

    topPadding: 0
    bottomPadding: 0
    leftPadding: 0
    rightPadding: 0

    function openSettingsModule(moduleName) {
        MobileShell.ShellUtil.executeCommand("plasma-open-settings " + moduleName);
    }

    ColumnLayout {
        FormCard.FormHeader {
            title: i18n("General")
        }

        FormCard.FormCard {
            FormCard.FormButtonDelegate {
                id: shellVibrationsButton
                text: i18n("Shell Vibrations")
                onClicked: kcm.push("VibrationForm.qml")
            }

            FormCard.FormDelegateSeparator { above: shellVibrationsButton; below: animationsSwitch }

            FormCard.FormSwitchDelegate {
                id: animationsSwitch
                text: i18n("Animations")
                description: i18n("If this is off, animations will be reduced as much as possible.")
                checked: ShellSettings.Settings.animationsEnabled
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.animationsEnabled) {
                        ShellSettings.Settings.animationsEnabled = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: animationsSwitch; below: doubleTapWakeup }

            FormCard.FormSwitchDelegate {
                id: doubleTapWakeup
                text: i18n("Double Tap to Wakeup")
                description: i18n("When the screen is off, double tap to wakeup the device.")
                checked: ShellSettings.KWinSettings.doubleTapWakeup
                onCheckedChanged: {
                    if (checked != ShellSettings.KWinSettings.doubleTapWakeup) {
                        ShellSettings.KWinSettings.doubleTapWakeup = checked;
                    }
                }
            }
        }

        FormCard.FormHeader {
            title: i18n("Convergence")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: convergenceModeSwitch
                text: i18n("Convergence Mode")
                description: i18n("Use desktop-style window placement, titlebar controls, Overview, and the dock.")
                checked: ShellSettings.Settings.convergenceModeEnabled
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.convergenceModeEnabled) {
                        ShellSettings.Settings.convergenceModeEnabled = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: convergenceModeSwitch; below: dynamicTilingSwitch }

            FormCard.FormSwitchDelegate {
                id: dynamicTilingSwitch
                text: i18n("Dynamic Tiling")
                description: i18n("Automatically arrange windows in convergence mode. Disabled while convergence mode is off or gaming mode is active.")
                enabled: ShellSettings.Settings.convergenceModeEnabled && !ShellSettings.Settings.gamingModeEnabled
                checked: ShellSettings.Settings.dynamicTilingEnabled
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.dynamicTilingEnabled) {
                        ShellSettings.Settings.dynamicTilingEnabled = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: dynamicTilingSwitch; below: snapLayoutsSwitch }

            FormCard.FormSwitchDelegate {
                id: snapLayoutsSwitch
                text: i18n("Snap Layouts")
                description: i18n("Show the snap layout picker from the maximize button. Disabled while convergence mode is off, gaming mode is active, or dynamic tiling is enabled.")
                enabled: ShellSettings.Settings.convergenceModeEnabled
                         && !ShellSettings.Settings.gamingModeEnabled
                         && !ShellSettings.Settings.dynamicTilingEnabled
                checked: ShellSettings.Settings.snapLayoutsEnabled
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.snapLayoutsEnabled) {
                        ShellSettings.Settings.snapLayoutsEnabled = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: snapLayoutsSwitch; below: autoHidePanels }

            FormCard.FormSwitchDelegate {
                id: autoHidePanels
                text: i18n("Auto Hide Panels")
                description: i18n("Allow maximized or fullscreen applications to reclaim panel and dock space.")
                checked: ShellSettings.Settings.autoHidePanelsEnabled
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.autoHidePanelsEnabled) {
                        ShellSettings.Settings.autoHidePanelsEnabled = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: autoHidePanels; below: displayConfigurationButton }

            FormCard.FormButtonDelegate {
                id: displayConfigurationButton
                icon.name: "preferences-desktop-display-randr"
                text: i18n("Display Configuration")
                onClicked: root.openSettingsModule("kcm_kscreen")
            }

            FormCard.FormDelegateSeparator { above: displayConfigurationButton; below: networkingButton }

            FormCard.FormButtonDelegate {
                id: networkingButton
                icon.name: "preferences-system-network"
                text: i18n("Wi-Fi & Networking")
                onClicked: root.openSettingsModule("kcm_networkmanagement")
            }

            FormCard.FormDelegateSeparator { above: networkingButton; below: soundButton }

            FormCard.FormButtonDelegate {
                id: soundButton
                icon.name: "preferences-desktop-sound"
                text: i18n("Sound")
                onClicked: root.openSettingsModule("kcm_pulseaudio")
            }

            FormCard.FormDelegateSeparator { above: soundButton; below: shortcutsButton }

            FormCard.FormButtonDelegate {
                id: shortcutsButton
                icon.name: "preferences-desktop-keyboard-shortcut"
                text: i18n("Shortcuts")
                onClicked: root.openSettingsModule("kcm_keys")
            }

            FormCard.FormDelegateSeparator { above: shortcutsButton; below: accessibilityButton }

            FormCard.FormButtonDelegate {
                id: accessibilityButton
                icon.name: "preferences-desktop-accessibility"
                text: i18n("Accessibility")
                onClicked: root.openSettingsModule("kcm_access")
            }

            FormCard.FormDelegateSeparator { above: accessibilityButton; below: notificationsButton }

            FormCard.FormButtonDelegate {
                id: notificationsButton
                icon.name: "preferences-desktop-notification-bell"
                text: i18n("Notifications")
                onClicked: root.openSettingsModule("kcm_notifications")
            }

            FormCard.FormDelegateSeparator { above: notificationsButton; below: screenLockingButton }

            FormCard.FormButtonDelegate {
                id: screenLockingButton
                icon.name: "preferences-desktop-user-password"
                text: i18n("Screen Locking")
                onClicked: root.openSettingsModule("kcm_screenlocker")
            }

            FormCard.FormDelegateSeparator { above: screenLockingButton; below: virtualKeyboardButton }

            FormCard.FormButtonDelegate {
                id: virtualKeyboardButton
                icon.name: "input-keyboard-virtual"
                text: i18n("Virtual Keyboard")
                onClicked: root.openSettingsModule("kcm_virtualkeyboard")
            }
        }

        FormCard.FormHeader {
            title: i18n("Desktop Workspace")
        }

        FormCard.FormCard {
            FormCard.FormButtonDelegate {
                id: virtualDesktopsButton
                icon.name: "preferences-desktop-virtual"
                text: i18n("Virtual Desktops")
                onClicked: root.openSettingsModule("kcm_kwin_virtualdesktops")
            }

            FormCard.FormDelegateSeparator { above: virtualDesktopsButton; below: windowBehaviorButton }

            FormCard.FormButtonDelegate {
                id: windowBehaviorButton
                icon.name: "preferences-system-windows-actions"
                text: i18n("Window Behavior")
                onClicked: root.openSettingsModule("kcm_kwinoptions")
            }

            FormCard.FormDelegateSeparator { above: windowBehaviorButton; below: windowRulesButton }

            FormCard.FormButtonDelegate {
                id: windowRulesButton
                icon.name: "preferences-system-windows-actions"
                text: i18n("Window Rules")
                onClicked: root.openSettingsModule("kcm_kwinrules")
            }

            FormCard.FormDelegateSeparator { above: windowRulesButton; below: taskSwitcherButton }

            FormCard.FormButtonDelegate {
                id: taskSwitcherButton
                icon.name: "preferences-system-tabbox"
                text: i18n("Task Switcher")
                onClicked: root.openSettingsModule("kcm_kwintabbox")
            }

            FormCard.FormDelegateSeparator { above: taskSwitcherButton; below: desktopEffectsButton }

            FormCard.FormButtonDelegate {
                id: desktopEffectsButton
                icon.name: "preferences-desktop-effects"
                text: i18n("Desktop Effects")
                onClicked: root.openSettingsModule("kcm_kwin_effects")
            }

            FormCard.FormDelegateSeparator { above: desktopEffectsButton; below: windowDecorationsButton }

            FormCard.FormButtonDelegate {
                id: windowDecorationsButton
                icon.name: "preferences-desktop-theme-windowdecorations"
                text: i18n("Window Decorations")
                onClicked: root.openSettingsModule("kcm_kwindecoration")
            }
        }

        FormCard.FormHeader {
            title: i18n("Status Bar")
        }

        FormCard.FormCard {
            FormCard.FormSwitchDelegate {
                id: dateInStatusBar
                text: i18n("Date in status bar")
                description: i18n("If on, date will be shown next to the clock in the status bar.")
                checked: ShellSettings.Settings.dateInStatusBar
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.dateInStatusBar) {
                        ShellSettings.Settings.dateInStatusBar = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: quickSettingsButton; below: topLeftActionDrawerModeDelegate }

            FormCard.FormSwitchDelegate {
                id: showBatteryPercentage
                text: i18n("Battery Percentage")
                description: i18n("Show battery percentage in the status bar.")
                checked: ShellSettings.Settings.showBatteryPercentage
                onCheckedChanged: {
                    if (checked != ShellSettings.Settings.showBatteryPercentage) {
                        ShellSettings.Settings.showBatteryPercentage = checked;
                    }
                }
            }

            FormCard.FormDelegateSeparator { above: quickSettingsButton; below: topLeftActionDrawerModeDelegate }

            FormCard.FormComboBoxDelegate {
                id: statusBarScaleFactorDelegate

                text: i18n("Status Bar Size")
                description: i18n("Size of the top panel (needs restart).")

                model: [
                    {"name": i18nc("Status bar height", "Tiny"), "value": 1.0},
                    {"name": i18nc("Status bar height", "Small"), "value": 1.15},
                    {"name": i18nc("Status bar height", "Normal"), "value": 1.25},
                    {"name": i18nc("Status bar height", "Large"), "value": 1.5},
                    {"name": i18nc("Status bar height", "Very Large"), "value": 2.0}
                ]

                textRole: "name"
                valueRole: "value"

                Component.onCompleted: {
                    currentIndex = indexOfValue(ShellSettings.Settings.statusBarScaleFactor);
                    dialog.parent = root;
                }
                onCurrentValueChanged: ShellSettings.Settings.statusBarScaleFactor = currentValue
            }

        }

        FormCard.FormHeader {
            title: i18n("Action Drawer")
        }

        FormCard.FormCard {
            id: quickSettings

            property string pinnedString: i18nc("Pinned action drawer mode", "Pinned Mode")
            property string expandedString: i18nc("Expanded action drawer mode", "Expanded Mode")

            FormCard.FormButtonDelegate {
                id: quickSettingsButton
                text: i18n("Quick Settings")
                onClicked: kcm.push("QuickSettingsForm.qml")
            }

            FormCard.FormDelegateSeparator { above: quickSettingsButton; below: topLeftActionDrawerModeDelegate }

            FormCard.FormComboBoxDelegate {
                id: topLeftActionDrawerModeDelegate
                text: i18n("Top Left Drawer Mode")
                description: i18n("Mode when opening from the top left.")

                model: [
                    {"name": quickSettings.pinnedString, "value": ShellSettings.Settings.Pinned},
                    {"name": quickSettings.expandedString, "value": ShellSettings.Settings.Expanded}
                ]

                textRole: "name"
                valueRole: "value"

                Component.onCompleted: {
                    currentIndex = indexOfValue(ShellSettings.Settings.actionDrawerTopLeftMode);
                    dialog.parent = root;
                }
                onCurrentValueChanged: ShellSettings.Settings.actionDrawerTopLeftMode = currentValue
            }

            FormCard.FormDelegateSeparator { above: topLeftActionDrawerModeDelegate; below: topRightActionDrawerModeDelegate }

            FormCard.FormComboBoxDelegate {
                id: topRightActionDrawerModeDelegate
                text: i18n("Top Right Drawer Mode")
                description: i18n("Mode when opening from the top right.")

                model: [
                    {"name": quickSettings.pinnedString, "value": ShellSettings.Settings.Pinned},
                    {"name": quickSettings.expandedString, "value": ShellSettings.Settings.Expanded}
                ]

                textRole: "name"
                valueRole: "value"

                Component.onCompleted: {
                    currentIndex = indexOfValue(ShellSettings.Settings.actionDrawerTopRightMode);
                    dialog.parent = root
                }
                onCurrentValueChanged: ShellSettings.Settings.actionDrawerTopRightMode = currentValue
            }
        }

        FormCard.FormHeader {
            title: i18nc("@title:group, shortcuts available from lock screen", "Lock Screen Shortcuts")
        }

        FormCard.FormCard {
            id: quickActionButtons
            property string noneString: i18nc("@item:inlistbox", "None")
            property string flashlightString: i18nc("@item:inlistbox", "Flashlight")
            property string cameraString: i18nc("@item:inlistbox", "Camera")

            FormCard.FormComboBoxDelegate {
                id: lockscreenLeftButtonDelegate
                text: i18nc("@label:listbox", "Left button")

                model: [
                    {"name": quickActionButtons.noneString, "value": ShellSettings.Settings.None},
                    {"name": quickActionButtons.flashlightString, "value": ShellSettings.Settings.Flashlight}
                    // {"name": quickActionButtons.cameraString, "value": ShellSettings.Settings.Camera}
                ]

                textRole: "name"
                valueRole: "value"

                Component.onCompleted: {
                    currentIndex = indexOfValue(ShellSettings.Settings.lockscreenLeftButtonAction);
                    dialog.parent = root;
                }
                onCurrentValueChanged: ShellSettings.Settings.lockscreenLeftButtonAction = currentValue
            }

            FormCard.FormDelegateSeparator { above: lockscreenRightButtonDelegate; below: lockscreenLeftButtonDelegate }

            FormCard.FormComboBoxDelegate {
                id: lockscreenRightButtonDelegate
                text: i18nc("@label:listbox", "Right button")

                model: [
                    {"name": quickActionButtons.noneString, "value": ShellSettings.Settings.None},
                    {"name": quickActionButtons.flashlightString, "value": ShellSettings.Settings.Flashlight}
                    // {"name": quickActionButtons.cameraString, "value": ShellSettings.Settings.Camera}
                ]

                textRole: "name"
                valueRole: "value"

                Component.onCompleted: {
                    currentIndex = indexOfValue(ShellSettings.Settings.lockscreenRightButtonAction);
                    dialog.parent = root;
                }
                onCurrentValueChanged: ShellSettings.Settings.lockscreenRightButtonAction = currentValue
            }
        }
    }
}
