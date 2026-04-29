/*
 *   SPDX-FileCopyrightText: 2021 Devin Lin <devin@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.1
import QtQuick.Layouts 1.1

import org.kde.kirigami as Kirigami

import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.nanoshell 2.0 as NanoShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.components 3.0 as PlasmaComponents

QuickSettingsDelegate {
    id: root

    iconItem: icon

    // scale animation on press
    zoomScale: (ShellSettings.Settings.animationsEnabled && mouseArea.pressed) ? 0.9 : 1

    background: Item {
        // very simple shadow for performance
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height

            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(0, 0, 0, 0.075)
        }

        // background
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            border.pixelAligned: false
            border.width: 1
            border.color: root.enabled ? root.enabledButtonBorderColor : root.disabledButtonBorderColor
            color: {
                if (root.enabled) {
                    if (mouseArea.pressed) {
                        return root.enabledButtonPressedColor
                    }
                    return mouseArea.containsMouse ? root.enabledButtonHoverColor : root.enabledButtonColor
                } else {
                    if (mouseArea.pressed) {
                        return root.disabledButtonPressedColor
                    }
                    return mouseArea.containsMouse ? root.disabledButtonHoverColor : root.disabledButtonColor
                }
            }

            Behavior on color {
                ColorAnimation { duration: ShellSettings.Settings.animationsEnabled ? Kirigami.Units.shortDuration : 0; easing.type: Easing.OutCubic }
            }
        }
    }

    MobileShell.HapticsEffect {
        id: haptics
    }

    contentItem: MouseArea {
        id: mouseArea
        hoverEnabled: true

        onPressed: haptics.buttonVibrate();
        onClicked: root.delegateClick()
        onPressAndHold: {
            haptics.buttonVibrate();
            root.delegatePressAndHold();
        }

        cursorShape: Qt.PointingHandCursor

        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: width
            source: root.icon
        }
    }
}

