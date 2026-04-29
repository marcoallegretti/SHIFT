/*
 *   SPDX-FileCopyrightText: 2015 Marco Martin <notmart@gmail.com>
 *   SPDX-FileCopyrightText: 2021 Devin Lin <devin@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Layouts 1.1

import org.kde.kirigami as Kirigami

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.components 3.0 as PlasmaComponents

QuickSettingsDelegate {
    id: root

    padding: Kirigami.Units.smallSpacing * 2
    iconItem: icon
    readonly property int tileRadius: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing

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

            radius: root.tileRadius
            color: Qt.rgba(0, 0, 0, root.enabled ? 0.12 : 0.08)
        }

        // background color
        Rectangle {
            id: tileRect
            anchors.fill: parent
            radius: root.tileRadius
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

        onPressed: haptics.buttonVibrate()
        onClicked: root.delegateClick()
        onPressAndHold: {
            haptics.buttonVibrate();
            root.delegatePressAndHold();
        }

        cursorShape: Qt.PointingHandCursor

        Kirigami.Icon {
            id: icon
            anchors.top: parent.top
            anchors.left: parent.left
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: width
            source: root.icon
        }

        ColumnLayout {
            id: column
            spacing: Kirigami.Units.smallSpacing
            anchors.right: parent.right
            anchors.left: parent.left
            anchors.bottom: parent.bottom

            MobileShell.MarqueeLabel {
                Layout.fillWidth: true
                inputText: root.text
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75 // TODO base height off of size of delegate
                font.weight: Font.Bold
            }

            MobileShell.MarqueeLabel {
                // if no status is given, just use On/Off
                inputText: root.status ? root.status : (root.enabled ? i18n("On") : i18n("Off"))
                opacity: 0.6

                Layout.fillWidth: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
            }
        }
    }
}

