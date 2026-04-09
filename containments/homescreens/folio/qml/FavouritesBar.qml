// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Layouts 1.1

import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.taskmanager as TaskManager
import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.kirigami as Kirigami
import QtQuick.Controls as Controls

import "./private"
import "./delegate"

MouseArea {
    id: root
    property Folio.HomeScreen folio
    property MobileShell.MaskManager maskManager

    property var homeScreen

    signal delegateDragRequested(var item)

    // Convergence mode: show running apps alongside favourites
    readonly property bool convergenceMode: ShellSettings.Settings.convergenceModeEnabled
    readonly property int totalItemCount: repeater.count + (convergenceMode ? taskRepeater.count : 0)

    // In convergence mode, size icons to fit the dock bar instead of using page grid cells
    readonly property real dockCellWidth: convergenceMode ? root.height : folio.HomeScreenState.pageCellWidth
    readonly property real dockCellHeight: convergenceMode ? root.height : folio.HomeScreenState.pageCellHeight

    // Navigation buttons width (used to offset center positioning)
    readonly property real navButtonWidth: convergenceMode ? root.height : 0

    // Center x for dock items (offset between nav buttons in convergence mode)
    readonly property real dockCenterX: convergenceMode
        ? navButtonWidth + (root.width - 2 * navButtonWidth) / 2
        : root.width / 2

    // Home button (convergence mode, left end)
    Rectangle {
        id: homeButton
        visible: root.convergenceMode
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: homeMouseArea.containsPress
            ? Qt.rgba(255, 255, 255, 0.2)
            : (homeMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
        radius: Kirigami.Units.cornerRadius

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.75
            height: width
            source: "start-here-kde"
            active: homeMouseArea.containsMouse
        }

        MouseArea {
            id: homeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: MobileShellState.ShellDBusClient.openHomeScreen()
        }

        Controls.ToolTip.text: i18n("Home")
        Controls.ToolTip.visible: homeMouseArea.containsMouse
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    // Overview button (convergence mode, right end)
    Rectangle {
        id: overviewButton
        visible: root.convergenceMode
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: overviewMouseArea.containsPress
            ? Qt.rgba(255, 255, 255, 0.2)
            : (overviewMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
        radius: Kirigami.Units.cornerRadius

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.75
            height: width
            source: "view-grid-symbolic"
            active: overviewMouseArea.containsMouse
        }

        MouseArea {
            id: overviewMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.folio.triggerOverview()
        }

        Controls.ToolTip.text: i18n("Overview")
        Controls.ToolTip.visible: overviewMouseArea.containsMouse
        Controls.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.TasksModel {
        id: tasksModel
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMaximized: false
        filterByScreen: true
        filterHidden: true
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressAndHold: {
        folio.HomeScreenState.openSettingsView();
        haptics.buttonVibrate();
    }

    onClicked: (mouse) => {
        // Right-click opens settings view (wallpaper/widgets), same as long-press
        if (mouse.button === Qt.RightButton) {
            folio.HomeScreenState.openSettingsView();
        }
    }

    onDoubleClicked: {
        if (folio.FolioSettings.doubleTapToLock) {
            deviceLock.triggerLock();
        }
    }

    onActiveFocusChanged: {
        if (activeFocus) {
            // Focus on first delegate when favorites bar focused
            let firstDelegate = repeater.itemAt(0);
            if (!firstDelegate) {
                return;
            }
            firstDelegate.keyboardFocus();
        }
    }

    MobileShell.HapticsEffect {
        id: haptics
    }

    MobileShell.DeviceLock {
        id: deviceLock
    }

    Repeater {
        id: repeater
        model: folio.FavouritesModel

        delegate: Item {
            id: delegate

            readonly property var delegateModel: model.delegate
            readonly property int index: model.index

            readonly property var dragState: folio.HomeScreenState.dragState
            readonly property bool isDropPositionThis: dragState.candidateDropPosition.location === Folio.DelegateDragPosition.Favourites &&
                dragState.candidateDropPosition.favouritesPosition === delegate.index
            readonly property bool isAppHoveredOver: folio.HomeScreenState.isDraggingDelegate &&
                dragState.dropDelegate &&
                dragState.dropDelegate.type === Folio.FolioDelegate.Application &&
                isDropPositionThis

            readonly property bool isLocationBottom: folio.HomeScreenState.favouritesBarLocation === Folio.HomeScreenState.Bottom

            // get the normalized index position value from the center so we can animate it
            property double fromCenterValue: model.index - (root.totalItemCount / 2)
            Behavior on fromCenterValue {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad; }
            }

            // multiply the 'fromCenterValue' by the cell size to get the actual position
            readonly property int centerPosition: (isLocationBottom ? root.dockCellWidth : root.dockCellHeight) * fromCenterValue

            x: isLocationBottom ? centerPosition + root.dockCenterX : (parent.width - width) / 2
            y: isLocationBottom ? (parent.height - height) / 2 : parent.height / 2 - centerPosition - root.dockCellHeight

            implicitWidth: root.dockCellWidth
            implicitHeight: root.dockCellHeight
            width: root.dockCellWidth
            height: root.dockCellHeight

            // Keyboard navigation to other delegates
            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_Up:
                    if (!isLocationBottom) {
                        let nextDelegate = repeater.itemAt(delegate.index - 1);
                        if (nextDelegate) {
                            nextDelegate.keyboardFocus();
                            event.accepted = true;
                        }
                    }
                    break;
                case Qt.Key_Down:
                    if (!isLocationBottom) {
                        let nextDelegate = repeater.itemAt(delegate.index + 1);
                        if (nextDelegate) {
                            nextDelegate.keyboardFocus();
                            event.accepted = true;
                        }
                    }
                    break;
                case Qt.Key_Left:
                    if (isLocationBottom) {
                        let nextDelegate = repeater.itemAt(delegate.index - 1);
                        if (nextDelegate) {
                            nextDelegate.keyboardFocus();
                            event.accepted = true;
                        }
                    }
                    break;
                case Qt.Key_Right:
                    if (isLocationBottom) {
                        let nextDelegate = repeater.itemAt(delegate.index + 1);
                        if (nextDelegate) {
                            nextDelegate.keyboardFocus();
                            event.accepted = true;
                        }
                    }
                    break;
                }
            }

            function keyboardFocus() {
                if (loader.item) {
                    loader.item.keyboardFocus();
                }
            }

            Loader {
                id: loader
                anchors.fill: parent

                sourceComponent: {
                    if (delegate.delegateModel.type === Folio.FolioDelegate.Application) {
                        return appComponent;
                    } else if (delegate.delegateModel.type === Folio.FolioDelegate.Folder) {
                        return folderComponent;
                    } else {
                        // ghost entry
                        return placeholderComponent;
                    }
                }
            }

            Component {
                id: placeholderComponent

                // square that shows when hovering over a spot to drop a delegate on (ghost entry)
                PlaceholderDelegate {
                    id: dragDropFeedback
                    folio: root.folio
                    width: root.dockCellWidth
                    height: root.dockCellHeight
                }
            }

            Component {
                id: appComponent

                AppDelegate {
                    id: appDelegate
                    folio: root.folio
                    maskManager: root.maskManager
                    application: delegate.delegateModel.application
                    name: folio.FolioSettings.showFavouritesAppLabels ? delegate.delegateModel.application.name : ""
                    shadow: true

                    turnToFolder: delegate.isAppHoveredOver
                    turnToFolderAnimEnabled: folio.HomeScreenState.isDraggingDelegate

                    // do not show if the drop animation is running to this delegate
                    visible: !(root.homeScreen.dropAnimationRunning && delegate.isDropPositionThis)

                    // don't show label in drag and drop mode
                    labelOpacity: delegate.opacity

                    onPressAndHold: {
                        // prevent editing if lock layout is enabled
                        if (folio.FolioSettings.lockLayout) return;

                        let mappedCoords = root.homeScreen.prepareStartDelegateDrag(delegate.delegateModel, appDelegate.delegateItem);
                        folio.HomeScreenState.startDelegateFavouritesDrag(
                            mappedCoords.x,
                            mappedCoords.y,
                            appDelegate.pressPosition.x,
                            appDelegate.pressPosition.y,
                            delegate.index
                        );

                        contextMenu.open();
                        haptics.buttonVibrate();
                    }

                    onPressAndHoldReleased: {
                        // cancel the event if the delegate is not dragged
                        if (folio.HomeScreenState.swipeState === Folio.HomeScreenState.AwaitingDraggingDelegate) {
                            homeScreen.cancelDelegateDrag();
                        }
                    }

                    onRightMousePress: {
                        contextMenu.open();
                    }

                    ContextMenuLoader {
                        id: contextMenu

                        // close menu when drag starts
                        Connections {
                            target: folio.HomeScreenState

                            function onDelegateDragStarted() {
                                contextMenu.close();
                            }
                        }

                        actions: [
                            Kirigami.Action {
                                icon.name: delegate.delegateModel.application.icon
                                text: i18n("Launch")
                                onTriggered: appDelegate.launchApp()
                            },
                            Kirigami.Action {
                                icon.name: "emblem-favorite"
                                text: i18n("Remove from Dock")
                                enabled: !folio.FolioSettings.lockLayout
                                onTriggered: folio.FavouritesModel.removeEntry(delegate.index)
                            }
                        ]
                    }
                }
            }

            Component {
                id: folderComponent

                AppFolderDelegate {
                    id: appFolderDelegate
                    folio: root.folio
                    maskManager: root.maskManager
                    shadow: true
                    folder: delegate.delegateModel.folder
                    name: folio.FolioSettings.showFavouritesAppLabels ? delegate.delegateModel.folder.name : ""

                    // do not show if the drop animation is running to this delegate, and the drop delegate is a folder
                    visible: !(root.homeScreen.dropAnimationRunning &&
                        delegate.isDropPositionThis &&
                        delegate.dragState.dropDelegate.type === Folio.FolioDelegate.Folder)

                    appHoveredOver: delegate.isAppHoveredOver

                    // don't show label in drag and drop mode
                    labelOpacity: delegate.opacity

                    onAfterClickAnimation: {
                        const pos = homeScreen.prepareFolderOpen(appFolderDelegate.contentItem);
                        folio.HomeScreenState.openFolder(pos.x, pos.y, delegate.delegateModel.folder);
                    }

                    onPressAndHold: {
                        let mappedCoords = root.homeScreen.prepareStartDelegateDrag(delegate.delegateModel, appFolderDelegate.delegateItem);
                        folio.HomeScreenState.startDelegateFavouritesDrag(
                            mappedCoords.x,
                            mappedCoords.y,
                            appFolderDelegate.pressPosition.x,
                            appFolderDelegate.pressPosition.y,
                            delegate.index
                        );

                        contextMenu.open();
                        haptics.buttonVibrate();
                    }

                    onPressAndHoldReleased: {
                        // cancel the event if the delegate is not dragged
                        if (folio.HomeScreenState.swipeState === Folio.HomeScreenState.AwaitingDraggingDelegate) {
                            root.homeScreen.cancelDelegateDrag();
                        }
                    }

                    onRightMousePress: {
                        contextMenu.open();
                    }

                    ContextMenuLoader {
                        id: contextMenu

                        // close menu when drag starts
                        Connections {
                            target: folio.HomeScreenState

                            function onDelegateDragStarted() {
                                contextMenu.close();
                            }
                        }

                        actions: [
                            Kirigami.Action {
                                icon.name: "emblem-favorite"
                                text: i18n("Remove")
                                onTriggered: deleteDialog.open()
                            }
                        ]

                        ConfirmDeleteFolderDialogLoader {
                            id: deleteDialog
                            parent: root.homeScreen
                            onAccepted: folio.FavouritesModel.removeEntry(delegate.index)
                        }
                    }
                }
            }
        }
    }

    // Running-app task icons (convergence mode only)
    Repeater {
        id: taskRepeater
        model: root.convergenceMode ? tasksModel : null

        delegate: Item {
            id: taskDelegate

            required property int index
            required property var model

            readonly property bool isLocationBottom: folio.HomeScreenState.favouritesBarLocation === Folio.HomeScreenState.Bottom

            // Position after all favourites
            property double fromCenterValue: (repeater.count + taskDelegate.index) - (root.totalItemCount / 2)
            Behavior on fromCenterValue {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad; }
            }

            readonly property int centerPosition: (isLocationBottom ? root.dockCellWidth : root.dockCellHeight) * fromCenterValue

            x: isLocationBottom ? centerPosition + root.dockCenterX : (parent.width - width) / 2
            y: isLocationBottom ? (parent.height - height) / 2 : parent.height / 2 - centerPosition - root.dockCellHeight

            implicitWidth: root.dockCellWidth
            implicitHeight: root.dockCellHeight
            width: root.dockCellWidth
            height: root.dockCellHeight

            // Hover highlight background
            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: taskMouseArea.containsPress
                    ? Qt.rgba(255, 255, 255, 0.2)
                    : (taskMouseArea.containsMouse ? Qt.rgba(255, 255, 255, 0.1) : "transparent")
            }

            // Task icon
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.6
                height: width
                source: taskDelegate.model.decoration
                active: taskMouseArea.containsMouse
            }

            // Active-window indicator dot
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
                width: Kirigami.Units.smallSpacing * 2
                height: width
                radius: width / 2
                color: Kirigami.Theme.highlightColor
                visible: taskDelegate.model.IsActive === true
            }

            // Click to activate
            MouseArea {
                id: taskMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        taskContextMenu.popup();
                    } else {
                        tasksModel.requestActivate(tasksModel.makeModelIndex(taskDelegate.index));
                    }
                }
            }

            Controls.ToolTip.text: taskDelegate.model.display || ""
            Controls.ToolTip.visible: taskMouseArea.containsMouse && (taskDelegate.model.display || "") !== ""
            Controls.ToolTip.delay: Kirigami.Units.toolTipDelay

            Controls.Menu {
                id: taskContextMenu
                Controls.MenuItem {
                    text: taskDelegate.model.IsMinimized ? i18n("Restore") : i18n("Minimize")
                    icon.name: taskDelegate.model.IsMinimized ? "window-restore" : "window-minimize"
                    onTriggered: tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                Controls.MenuItem {
                    text: taskDelegate.model.IsMaximized ? i18n("Restore") : i18n("Maximize")
                    icon.name: taskDelegate.model.IsMaximized ? "window-restore" : "window-maximize"
                    onTriggered: tasksModel.requestToggleMaximized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                Controls.MenuSeparator {}
                Controls.MenuItem {
                    text: i18n("Close")
                    icon.name: "window-close"
                    onTriggered: tasksModel.requestClose(tasksModel.makeModelIndex(taskDelegate.index))
                }
            }
        }
    }
}
