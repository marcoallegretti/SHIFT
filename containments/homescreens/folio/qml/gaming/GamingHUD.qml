// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell
import org.kde.layershell 1.0 as LayerShell

Window {
    id: root

    signal openRequested()

    // Guard against startup timing where Kirigami units may briefly be 0/NaN.
    // LayerShell surfaces must never be committed with zero size.
    readonly property real safeGridUnit: ((Kirigami.Units.gridUnit || 0) > 0) ? Kirigami.Units.gridUnit : 16
    width: safeGridUnit * 4
    height: safeGridUnit * 2
    color: "transparent"
    flags: Qt.FramelessWindowHint

    LayerShell.Window.scope: "gaming-hud"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Driven by the Loader in folio/qml/main.qml — set false to fade out
    // before the Loader destroys the window.
    property bool showing: true

    opacity: showing ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)

        Row {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                icon.name: "input-gaming"
                icon.color: "white"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Game Center")
                onClicked: root.openRequested()
            }

            // Show primary gamepad battery when connected
            QQC2.Label {
                visible: GamingShell.GamepadManager.hasGamepad
                         && GamingShell.GamepadManager.primaryGamepad
                         && GamingShell.GamepadManager.primaryGamepad.batteryPercent >= 0
                text: GamingShell.GamepadManager.primaryGamepad
                      ? GamingShell.GamepadManager.primaryGamepad.batteryPercent + "%"
                      : ""
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
