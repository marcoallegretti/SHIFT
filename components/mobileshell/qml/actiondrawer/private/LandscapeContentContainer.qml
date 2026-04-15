// SPDX-FileCopyrightText: 2021-2024 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS

/**
 * Root element that contains all the ActionDrawer's contents, and is anchored to the screen.
 */
Item {
    id: root

    required property var actionDrawer

    property alias quickSettings: quickSettingsPanel.quickSettings
    property alias statusBar: quickSettingsPanel.statusBar

    readonly property real minimizedQuickSettingsOffset: height
    readonly property real maximizedQuickSettingsOffset: height
    readonly property bool isOnLargeScreen: width > quickSettingsPanel.width * 2.5
    readonly property real minWidthHeight: Math.min(root.width, root.height)
    readonly property real opacityValue: Math.max(0, Math.min(1, actionDrawer.offsetResistance / root.minimizedQuickSettingsOffset))
    readonly property double brightnessPressedValue: quickSettings.brightnessPressedValue

    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    MouseArea {
        anchors.fill: parent

        // dismiss drawer when background is clicked
        onClicked: root.actionDrawer.close();

        // right sidebar
        MobileShell.QuickSettingsPanel {
            id: quickSettingsPanel
            height: quickSettingsPanel.contentImplicitHeight + quickSettingsPanel.topPadding + quickSettingsPanel.bottomPadding
            width: intendedWidth

            readonly property real columnWidth: 6 * Kirigami.Units.gridUnit
            // In convergence mode, use up to 45% of screen width so more
            // tiles are visible without pagination.
            readonly property int convergenceColumns: Math.min(6, Math.floor(root.width * 0.45 / columnWidth))
            readonly property int effectiveColumns: ShellSettings.Settings.convergenceModeEnabled
                ? Math.max(ShellSettings.Settings.quickSettingsColumns, convergenceColumns)
                : ShellSettings.Settings.quickSettingsColumns
            readonly property real intendedWidth: (columnWidth * effectiveColumns) + Kirigami.Units.gridUnit

            property real offsetRatio: quickSettingsPanel.height / root.height
            anchors.topMargin: Math.min(root.actionDrawer.offsetResistance * offsetRatio - quickSettingsPanel.height, 0)
            anchors.top: parent.top
            anchors.right: parent.right

            actionDrawer: root.actionDrawer
            fullScreenHeight: root.height
        }
    }
}
