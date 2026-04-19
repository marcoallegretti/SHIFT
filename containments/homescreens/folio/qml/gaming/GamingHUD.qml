// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.layershell 1.0 as LayerShell

Window {
    id: root

    signal openRequested()

    width: Kirigami.Units.gridUnit * 4
    height: Kirigami.Units.gridUnit * 2
    color: "transparent"
    flags: Qt.FramelessWindowHint

    LayerShell.Window.scope: "gaming-hud"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    opacity: visible ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)

        QQC2.ToolButton {
            anchors.centerIn: parent
            icon.name: "input-gaming"
            icon.color: "white"
            display: QQC2.AbstractButton.IconOnly
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: i18n("Game Center")
            onClicked: root.openRequested()
        }
    }
}
