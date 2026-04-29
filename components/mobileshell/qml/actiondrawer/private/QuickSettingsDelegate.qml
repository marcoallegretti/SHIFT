/*
 *   SPDX-FileCopyrightText: 2015 Marco Martin <notmart@gmail.com>
 *   SPDX-FileCopyrightText: 2021 Devin Lin <devin@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.1
import QtQuick.Layouts 1.1

import org.kde.kirigami as Kirigami

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.nanoshell 2.0 as NanoShell
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.components 3.0 as PlasmaComponents

MobileShell.BaseItem {
    id: root

    required property bool restrictedPermissions

    // Model interface
    required property string text
    required property string status
    required property string icon
    required property bool enabled
    required property string settingsCommand
    required property var toggleFunction

    signal closeRequested()
    signal detailRequested(string pluginId)

    // set by children
    property var iconItem

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Button

    readonly property color enabledButtonBorderColor: Qt.darker(Kirigami.Theme.highlightColor, 1.25)
    readonly property color disabledButtonBorderColor: separatorColorHelper(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
    readonly property color enabledButtonColor: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.25)
    readonly property color enabledButtonHoverColor: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.32)
    readonly property color enabledButtonPressedColor: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.12);
    readonly property color disabledButtonColor: Kirigami.Theme.alternateBackgroundColor
    readonly property color disabledButtonHoverColor: mixColor(Kirigami.Theme.alternateBackgroundColor, Kirigami.Theme.textColor, 0.06)
    readonly property color disabledButtonPressedColor: Qt.darker(disabledButtonColor, 1.1)

    function mixColor(base, overlay, ratio) {
        return Qt.rgba(
            base.r + (overlay.r - base.r) * ratio,
            base.g + (overlay.g - base.g) * ratio,
            base.b + (overlay.b - base.b) * ratio,
            base.a + (overlay.a - base.a) * ratio)
    }

    function separatorColorHelper(bg, fg, baseRatio) {
        if (Kirigami.ColorUtils.brightnessForColor(bg) === Kirigami.ColorUtils.Light) {
            return Kirigami.ColorUtils.linearInterpolation(bg, fg, baseRatio);
        } else {
            return Kirigami.ColorUtils.linearInterpolation(bg, fg, baseRatio / 2);
        }
    }

    // scale animation on press
    property real zoomScale: 1
    Behavior on zoomScale {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutExpo
        }
    }

    transform: Scale {
        origin.x: root.width / 2;
        origin.y: root.height / 2;
        xScale: root.zoomScale
        yScale: root.zoomScale
    }

    function delegateClick() {
        if (root.toggle) {
            root.toggle();
        } else if (root.toggleFunction) {
            root.toggleFunction();
        } else if (root.settingsCommand && !root.restrictedPermissions) {
            closeRequested();

            MobileShellState.ShellDBusClient.openAppLaunchAnimationWithPosition(
                __getCurrentScreenNumber(),
                root.icon,
                root.text,
                'org.kde.mobile.plasmasettings', // settings window id
                -1,
                -1,
                Math.min(root.iconItem.width, root.iconItem.height));
            MobileShell.ShellUtil.executeCommand(root.settingsCommand);
        }
    }

    // Map quick-setting settingsCommand → desktop Plasma applet pluginId.
    // Only tiles listed here get an inline detail popup in convergence mode.
    readonly property var __appletForCommand: ({
        "plasma-open-settings kcm_mobile_wifi": "org.kde.plasma.networkmanagement",
        "plasma-open-settings kcm_bluetooth": "org.kde.plasma.bluetooth",
        "plasma-open-settings kcm_pulseaudio": "org.kde.plasma.volume",
        "plasma-open-settings kcm_mobile_power": "org.kde.plasma.battery",
    })

    function delegatePressAndHold() {
        // In convergence mode, show inline detail popup if available.
        if (ShellSettings.Settings.convergenceModeEnabled && root.settingsCommand && !root.restrictedPermissions) {
            let pluginId = __appletForCommand[root.settingsCommand];
            if (pluginId) {
                root.detailRequested(pluginId);
                return;
            }
        }

        if (root.settingsCommand && !root.restrictedPermissions) {
            closeRequested();
            MobileShellState.ShellDBusClient.openAppLaunchAnimationWithPosition(
                __getCurrentScreenNumber(),
                root.icon,
                root.text,
                'org.kde.mobile.plasmasettings', // settings window id
                -1,
                -1,
                Math.min(root.iconItem.width, root.iconItem.height));
            MobileShell.ShellUtil.executeCommand(root.settingsCommand);
        } else if (root.toggleFunction) {
            root.toggleFunction();
        }
    }

    function __getCurrentScreenNumber() {
        const screens = Qt.application.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === Screen.name) {
                return i;
            }
        }

        return 0;
    }
}
