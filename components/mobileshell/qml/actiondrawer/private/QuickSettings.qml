/*
 *   SPDX-FileCopyrightText: 2014 Marco Martin <notmart@gmail.com>
 *   SPDX-FileCopyrightText: 2021 Devin Lin <devin@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2

import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.kirigami as Kirigami

/**
 * Quick settings elements layout, change the height to clip.
 */
Item {
    id: root
    // to prevent clipping off the shadows form the BrightnessItem when the rest of the action panel view
    // is transparent, we stop clipping the base view when fullViewProgress is not less then 1
    clip: fullViewProgress < 1

    required property var actionDrawer

    required property QS.QuickSettingsModel quickSettingsModel

    readonly property real columns: Math.round(Math.min(6, Math.max(ShellSettings.Settings.quickSettingsColumns, width / intendedColumnWidth)))
    readonly property real columnWidth: Math.floor(width / columns)
    readonly property int minimizedColumns: Math.round(Math.min(8, Math.max(5, width / intendedMinimizedColumnWidth)))
    readonly property real minimizedColumnWidth: Math.floor(width / minimizedColumns)

    readonly property real rowHeight: columnWidth * 0.7
    readonly property real fullHeight: fullView.implicitHeight

    readonly property real intendedColumnWidth: Kirigami.Units.gridUnit * 7
    readonly property real intendedMinimizedColumnWidth: Kirigami.Units.gridUnit * 4 + Kirigami.Units.smallSpacing
    readonly property real minimizedRowHeight: Kirigami.Units.gridUnit * 4 + Kirigami.Units.smallSpacing

    property real fullViewProgress: 1

    readonly property int columnCount: Math.floor(width/columnWidth)
    readonly property int rowCount: {
        let totalRows = Math.ceil(quickSettingsCount / columnCount);
        let maxRows = root.isConvergence ? 3 : 5; // more than 5 is just disorienting
        let targetRows = Math.floor(Window.height * (root.isConvergence ? 0.42 : 0.65) / rowHeight);
        return Math.max(1, Math.min(maxRows, Math.min(totalRows, targetRows)));
    }

    readonly property int pageSize: rowCount * columnCount
    readonly property int quickSettingsCount: quickSettingsModel.count

    // Management tiles — promoted to full-width status rows in convergence.
    readonly property var __managementCommands: ({
        "plasma-open-settings kcm_mobile_wifi": "org.kde.plasma.networkmanagement",
        "plasma-open-settings kcm_bluetooth": "org.kde.plasma.bluetooth",
        "plasma-open-settings kcm_pulseaudio": "org.kde.plasma.volume",
        "plasma-open-settings kcm_mobile_power": "org.kde.plasma.battery",
    })
    readonly property bool isConvergence: ShellSettings.Settings.convergenceModeEnabled
    function isManagementTile(cmd) { return cmd in __managementCommands; }
    readonly property int promotedColumns: isConvergence && width >= Kirigami.Units.gridUnit * 18 ? 2 : 1
    readonly property real promotedSpacing: Kirigami.Units.smallSpacing
    readonly property real promotedHorizontalMargin: Kirigami.Units.smallSpacing
    readonly property real promotedCellWidth: Math.floor((width - 2 * promotedHorizontalMargin - (promotedColumns - 1) * promotedSpacing) / promotedColumns)

    readonly property alias brightnessPressedValue: brightnessItem.brightnessPressedValue

    function resetSwipeView() {
        swipeView.currentIndex = 0;
    }

    // return to the first page when the action drawer is closed
    Connections {
        target: actionDrawer

        function onOpenedChanged() {
            if (!actionDrawer.opened) {
                resetSwipeView();
            }
        }
    }

    // view when in minimized mode
    RowLayout {
        id: minimizedView
        spacing: 0
        opacity: 1 - root.fullViewProgress

        anchors.topMargin: root.fullViewProgress * -height
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            id: repeater
            model: QS.PaginateModel {
                sourceModel: root.quickSettingsModel
                pageSize: Math.min(root.pageSize, root.minimizedColumns) // HACK: just root.minimizedColumns appears to end up with an empty model?
            }
            delegate: MobileShell.BaseItem {
                required property var modelData

                implicitHeight: root.minimizedRowHeight
                implicitWidth: root.minimizedColumnWidth
                horizontalPadding: (width - Kirigami.Units.gridUnit * 3) / 2
                verticalPadding: (height - Kirigami.Units.gridUnit * 3) / 2

                contentItem: QuickSettingsMinimizedDelegate {
                    restrictedPermissions: actionDrawer.restrictedPermissions

                    text: modelData.text
                    status: modelData.status
                    icon: modelData.icon
                    enabled: modelData.enabled
                    settingsCommand: modelData.settingsCommand
                    toggleFunction: modelData.toggle

                    onCloseRequested: {
                        actionDrawer.close();
                    }
                    onDetailRequested: (pluginId) => {
                        detailPopup.show(pluginId);
                    }
                }
            }
        }
    }

    // view when fully open
    ColumnLayout {
        id: fullView
        opacity: root.fullViewProgress

        anchors.top: minimizedView.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Promoted desktop controls (convergence mode only)
        GridLayout {
            id: promotedGrid
            Layout.fillWidth: true
            Layout.leftMargin: root.promotedHorizontalMargin
            Layout.rightMargin: root.promotedHorizontalMargin
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            columns: root.promotedColumns
            rowSpacing: root.promotedSpacing
            columnSpacing: root.promotedSpacing
            visible: root.isConvergence

            Repeater {
                model: [
                    {
                        text: i18n("Clipboard"),
                        status: i18n("History"),
                        icon: "klipper-symbolic",
                        pluginId: "org.kde.plasma.clipboard"
                    },
                    {
                        text: i18n("Disks & Devices"),
                        status: i18n("Removable media"),
                        icon: "device-notifier-symbolic",
                        pluginId: "org.kde.plasma.devicenotifier"
                    },
                    {
                        text: i18n("System Tray"),
                        status: systemTrayPopup.trayItemCount > 0 ? i18np("%1 status item", "%1 status items", systemTrayPopup.trayItemCount) : i18n("No status items"),
                        icon: "preferences-desktop-notification-symbolic",
                        trayPopup: true
                    }
                ]

                delegate: QuickSettingsStatusRow {
                    required property var modelData
                    Layout.preferredWidth: root.promotedCellWidth
                    Layout.fillWidth: true
                    compact: true
                    text: modelData.text
                    status: modelData.status
                    icon: modelData.icon
                    enabled: false
                    toggleFunction: null
                    onDetailClicked: {
                        if (modelData.trayPopup) {
                            systemTrayPopup.show();
                        } else {
                            detailPopup.show(modelData.pluginId);
                        }
                    }
                }
            }

            Repeater {
                model: root.quickSettingsModel
                delegate: QuickSettingsStatusRow {
                    required property var modelData
                    readonly property bool isPromoted: root.isManagementTile(modelData.settingsCommand)
                    Layout.preferredWidth: isPromoted ? root.promotedCellWidth : 0
                    Layout.preferredHeight: isPromoted ? implicitHeight : 0
                    Layout.maximumWidth: isPromoted ? root.promotedCellWidth : 0
                    Layout.maximumHeight: isPromoted ? implicitHeight : 0
                    Layout.fillWidth: true
                    visible: isPromoted
                    compact: true
                    text: modelData.text
                    status: modelData.status
                    icon: modelData.icon
                    enabled: modelData.enabled
                    toggleFunction: modelData.toggle
                    onDetailClicked: {
                        let pluginId = root.__managementCommands[modelData.settingsCommand];
                        if (pluginId) detailPopup.show(pluginId);
                    }
                }
            }
        }

        // Quick settings view
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumHeight: rowCount * rowHeight

            opacity: brightnessPressedValue

            SwipeView {
                id: swipeView
                // we need to clip this view here to prevent the other quick settings pages from being visible
                // when fullViewProgress is not less then 1 and the base view is no longer being clipped
                clip: true

                Layout.fillWidth: true
                Layout.preferredHeight: rowCount * rowHeight

                Repeater {
                    model: Math.ceil(quickSettingsCount / pageSize)
                    delegate: Flow {
                        id: flow
                        spacing: 0

                        required property int index

                        Repeater {
                            model: QS.PaginateModel {
                                sourceModel: quickSettingsModel
                                pageSize: root.pageSize
                                firstItem: pageSize * flow.index
                            }
                            delegate: MobileShell.BaseItem {
                                required property var modelData

                                readonly property bool __hidden: root.isConvergence && root.isManagementTile(modelData.settingsCommand)
                                height: __hidden ? 0 : root.rowHeight
                                width: __hidden ? 0 : root.columnWidth
                                visible: !__hidden
                                padding: Kirigami.Units.smallSpacing

                                contentItem: QuickSettingsFullDelegate {
                                    restrictedPermissions: actionDrawer.restrictedPermissions

                                    text: modelData.text
                                    status: modelData.status
                                    icon: modelData.icon
                                    enabled: modelData.enabled
                                    settingsCommand: modelData.settingsCommand
                                    toggleFunction: modelData.toggle

                                    onCloseRequested: {
                                        actionDrawer.close();
                                    }
                                    onDetailRequested: (pluginId) => {
                                        detailPopup.show(pluginId);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: indicatorLoader

                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing

                // Avoid wasting space when not loaded
                Layout.maximumHeight: active ? item.implicitHeight : 0

                active: swipeView.count > 1 ? true: false
                asynchronous: true

                sourceComponent: PageIndicator {
                    id: pageIndicatorItem
                    count: swipeView.count
                    currentIndex: swipeView.currentIndex
                    interactive: true
                    onCurrentIndexChanged: {
                        if (swipeView.currentIndex !== currentIndex)
                            swipeView.currentIndex = currentIndex;
                    }

                    Connections {
                        target: swipeView
                        function onCurrentIndexChanged() {
                            if (pageIndicatorItem.currentIndex !== swipeView.currentIndex)
                                pageIndicatorItem.currentIndex = swipeView.currentIndex;
                        }
                    }

                    delegate: Rectangle {
                        implicitWidth: 8
                        implicitHeight: count > 1 ? 8 : 0

                        radius: parent.width / 2
                        color: Kirigami.Theme.disabledTextColor

                        opacity: index === currentIndex ? 0.95 : 0.45
                    }
                }
            }
        }

        // Brightness slider
        BrightnessItem {
            id: brightnessItem
            Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
        }
    }

    DetailPopup {
        id: detailPopup
        parent: root.Window.window ? root.Window.window.contentItem : root
    }

    SystemTrayPopup {
        id: systemTrayPopup
        parent: root.Window.window ? root.Window.window.contentItem : root
    }

}
