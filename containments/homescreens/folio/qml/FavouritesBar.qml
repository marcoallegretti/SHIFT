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
import QtQuick.Templates as T

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

    // Visible spacer between pinned favourites and running tasks
    readonly property bool showSpacer: convergenceMode && repeater.count > 0 && taskRepeater.count > 0
    property real spacerWidth: showSpacer ? Kirigami.Units.largeSpacing * 2 : 0
    Behavior on spacerWidth {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    // Thumbnail popup hover tracking
    property int hoveredTaskIndex: -1

    // Drag-reorder state (convergence mode only)
    property int dragReorderIndex: -1
    property real dragReorderOffset: 0
    readonly property int dragTargetIndex: {
        if (dragReorderIndex === -1) return -1
        let shift = Math.round(dragReorderOffset / dockCellWidth)
        return Math.max(0, Math.min(repeater.count - 1, dragReorderIndex + shift))
    }

    // Drag-to-pin state for running tasks in convergence mode.
    property int taskPinDragIndex: -1
    property real taskPinDragOffset: 0
    property int taskPinTargetIndex: -1
    property string taskPinStorageId: ""
    readonly property bool taskPinCanDrop: taskPinTargetIndex !== -1 && taskPinStorageId !== ""

    function runningTaskStorageId(taskModel) {
        var id = taskModel ? taskModel.AppId || "" : ""
        if (id && !id.endsWith(".desktop"))
            id += ".desktop"
        return id
    }

    function favouriteBaseX(index) {
        return index * root.dockCellWidth - (root.totalItemCount / 2) * root.dockCellWidth + root.dockCenterX - root.spacerWidth / 2
    }

    function taskBaseX(index) {
        return (repeater.count + index) * root.dockCellWidth - (root.totalItemCount / 2) * root.dockCellWidth + root.dockCenterX + root.spacerWidth / 2
    }

    function clearTaskPinDrag() {
        root.taskPinDragIndex = -1
        root.taskPinDragOffset = 0
        root.taskPinTargetIndex = -1
        root.taskPinStorageId = ""
    }

    function updateTaskPinTarget() {
        if (root.taskPinDragIndex === -1 || root.taskPinStorageId === "" || folio.FolioSettings.lockLayout || folio.FavouritesModel.containsApplication(root.taskPinStorageId)) {
            root.taskPinTargetIndex = -1
            return
        }

        var draggedCenterX = root.taskBaseX(root.taskPinDragIndex) + root.dockCellWidth / 2 + root.taskPinDragOffset
        var firstTaskCenterX = root.taskBaseX(0) + root.dockCellWidth / 2

        if (draggedCenterX >= firstTaskCenterX) {
            root.taskPinTargetIndex = -1
            return
        }

        if (repeater.count === 0) {
            root.taskPinTargetIndex = 0
            return
        }

        for (let index = 0; index < repeater.count; ++index) {
            let favouriteCenterX = root.favouriteBaseX(index) + root.dockCellWidth / 2
            if (draggedCenterX < favouriteCenterX) {
                root.taskPinTargetIndex = index
                return
            }
        }

        root.taskPinTargetIndex = repeater.count
    }

    // Home button (convergence mode, left end)
    Rectangle {
        id: homeButton
        visible: root.convergenceMode
        activeFocusOnTab: root.convergenceMode
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: homeMouseArea.containsPress
            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
            : (homeMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1) : "transparent")
        radius: Kirigami.Units.cornerRadius

        Accessible.role: Accessible.Button
        Accessible.name: i18n("Home")
        Accessible.onPressAction: MobileShellState.ShellDBusClient.openHomeScreen()

        Keys.onReturnPressed: MobileShellState.ShellDBusClient.openHomeScreen()
        Keys.onEnterPressed: MobileShellState.ShellDBusClient.openHomeScreen()
        Keys.onSpacePressed: MobileShellState.ShellDBusClient.openHomeScreen()
        Keys.onRightPressed: {
            let first = repeater.itemAt(0)
            if (first) { first.keyboardFocus(); return }
            let firstTask = taskRepeater.itemAt(0)
            if (firstTask) { firstTask.forceActiveFocus(); return }
            overviewButton.forceActiveFocus()
        }

        KeyboardHighlight {
            anchors.fill: parent
            visible: homeButton.activeFocus
        }

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
            cursorShape: root.convergenceMode ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: MobileShellState.ShellDBusClient.openHomeScreen()
        }
    }

    // Overview button (convergence mode, right end)
    Rectangle {
        id: overviewButton
        visible: root.convergenceMode
        activeFocusOnTab: root.convergenceMode
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: overviewMouseArea.containsPress
            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
            : (overviewMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1) : "transparent")
        radius: Kirigami.Units.cornerRadius

        Accessible.role: Accessible.Button
        Accessible.name: i18n("Overview")
        Accessible.onPressAction: root.folio.triggerOverview()

        Keys.onReturnPressed: root.folio.triggerOverview()
        Keys.onEnterPressed: root.folio.triggerOverview()
        Keys.onSpacePressed: root.folio.triggerOverview()
        Keys.onLeftPressed: {
            let lastTask = taskRepeater.itemAt(taskRepeater.count - 1)
            if (lastTask) { lastTask.forceActiveFocus(); return }
            let lastFav = repeater.itemAt(repeater.count - 1)
            if (lastFav) { lastFav.keyboardFocus(); return }
            homeButton.forceActiveFocus()
        }

        KeyboardHighlight {
            anchors.fill: parent
            visible: overviewButton.activeFocus
        }

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
            cursorShape: root.convergenceMode ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.folio.triggerOverview()
        }
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
        filterHidden: false
        virtualDesktop: virtualDesktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupApplications
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

            // Visual shift during drag-reorder: dragged item follows cursor,
            // displaced items slide to make room.
            property real dragVisualShift: {
                if (root.dragReorderIndex === -1) return 0
                if (delegate.index === root.dragReorderIndex) return root.dragReorderOffset
                let targetIdx = root.dragTargetIndex
                let myIdx = delegate.index
                let dragIdx = root.dragReorderIndex
                let cellW = root.dockCellWidth
                if (targetIdx > dragIdx && myIdx > dragIdx && myIdx <= targetIdx) return -cellW
                if (targetIdx < dragIdx && myIdx >= targetIdx && myIdx < dragIdx) return cellW
                return 0
            }
            Behavior on dragVisualShift {
                enabled: root.dragReorderIndex !== -1 && delegate.index !== root.dragReorderIndex
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            property real taskPinVisualShift: root.taskPinCanDrop && delegate.index >= root.taskPinTargetIndex ? root.dockCellWidth : 0

            x: (isLocationBottom ? root.favouriteBaseX(delegate.index) : (parent.width - width) / 2) + dragVisualShift + taskPinVisualShift
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
                        let prevDelegate = repeater.itemAt(delegate.index - 1);
                        if (prevDelegate) {
                            prevDelegate.keyboardFocus();
                            event.accepted = true;
                        } else if (root.convergenceMode) {
                            homeButton.forceActiveFocus();
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
                        } else if (root.convergenceMode) {
                            let firstTask = taskRepeater.itemAt(0);
                            if (firstTask) {
                                firstTask.forceActiveFocus();
                            } else {
                                overviewButton.forceActiveFocus();
                            }
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

                    // Convergence drag-reorder: click-and-drag to reorder
                    onDraggingChanged: {
                        if (root.convergenceMode && !folio.FolioSettings.lockLayout) {
                            if (appDelegate.dragging) {
                                contextMenu.close()
                                root.dragReorderIndex = delegate.index
                                root.dragReorderOffset = 0
                            } else {
                                let from = root.dragReorderIndex
                                let to = root.dragTargetIndex
                                root.dragReorderIndex = -1
                                root.dragReorderOffset = 0
                                if (from !== -1 && to !== -1 && from !== to) {
                                    folio.FavouritesModel.moveEntry(from, to)
                                }
                            }
                        }
                    }

                    onDragMoved: (deltaX) => {
                        if (root.convergenceMode && !folio.FolioSettings.lockLayout) {
                            root.dragReorderOffset = deltaX
                        }
                    }

                    onPressAndHold: {
                        // prevent editing if lock layout is enabled
                        if (folio.FolioSettings.lockLayout) return;

                        // In convergence mode, drag-reorder is handled by DragHandler;
                        // only open the context menu on press-and-hold.
                        if (!root.convergenceMode) {
                            let mappedCoords = root.homeScreen.prepareStartDelegateDrag(delegate.delegateModel, appDelegate.delegateItem);
                            folio.HomeScreenState.startDelegateFavouritesDrag(
                                mappedCoords.x,
                                mappedCoords.y,
                                appDelegate.pressPosition.x,
                                appDelegate.pressPosition.y,
                                delegate.index
                            );
                        }

                        contextMenu.open();
                        haptics.buttonVibrate();
                    }

                    onPressAndHoldReleased: {
                        // cancel the event if the delegate is not dragged
                        if (!root.convergenceMode && folio.HomeScreenState.swipeState === Folio.HomeScreenState.AwaitingDraggingDelegate) {
                            homeScreen.cancelDelegateDrag();
                        }
                    }

                    onRightMousePress: {
                        contextMenu.open();
                    }

                    ContextMenuLoader {
                        id: contextMenu
                        menuPopupType: root.convergenceMode ? T.Popup.Window : T.Popup.Item

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

                    // Convergence drag-reorder: click-and-drag to reorder
                    onDraggingChanged: {
                        if (root.convergenceMode && !folio.FolioSettings.lockLayout) {
                            if (appFolderDelegate.dragging) {
                                contextMenu.close()
                                root.dragReorderIndex = delegate.index
                                root.dragReorderOffset = 0
                            } else {
                                let from = root.dragReorderIndex
                                let to = root.dragTargetIndex
                                root.dragReorderIndex = -1
                                root.dragReorderOffset = 0
                                if (from !== -1 && to !== -1 && from !== to) {
                                    folio.FavouritesModel.moveEntry(from, to)
                                }
                            }
                        }
                    }

                    onDragMoved: (deltaX) => {
                        if (root.convergenceMode && !folio.FolioSettings.lockLayout) {
                            root.dragReorderOffset = deltaX
                        }
                    }

                    onPressAndHold: {
                        // prevent editing if lock layout is enabled
                        if (folio.FolioSettings.lockLayout) return;

                        if (!root.convergenceMode) {
                            let mappedCoords = root.homeScreen.prepareStartDelegateDrag(delegate.delegateModel, appFolderDelegate.delegateItem);
                            folio.HomeScreenState.startDelegateFavouritesDrag(
                                mappedCoords.x,
                                mappedCoords.y,
                                appFolderDelegate.pressPosition.x,
                                appFolderDelegate.pressPosition.y,
                                delegate.index
                            );
                        }

                        contextMenu.open();
                        haptics.buttonVibrate();
                    }

                    onPressAndHoldReleased: {
                        // cancel the event if the delegate is not dragged
                        if (!root.convergenceMode && folio.HomeScreenState.swipeState === Folio.HomeScreenState.AwaitingDraggingDelegate) {
                            root.homeScreen.cancelDelegateDrag();
                        }
                    }

                    onRightMousePress: {
                        contextMenu.open();
                    }

                    ContextMenuLoader {
                        id: contextMenu
                        menuPopupType: root.convergenceMode ? T.Popup.Window : T.Popup.Item

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

    Timer {
        id: thumbnailShowTimer
        interval: Kirigami.Units.toolTipDelay
        onTriggered: {
            thumbnailPopup.showing = true
        }
    }

    Timer {
        id: thumbnailHideTimer
        interval: 300
        onTriggered: {
            thumbnailPopup.showing = false
            root.hoveredTaskIndex = -1
        }
    }

    Window {
        id: thumbnailPopup

        property var targetDelegate: null
        property int taskIndex: -1
        property var windowIds: []
        property bool isGroup: false
        property bool popupHovered: false
        property bool showing: false

        function open() { showing = true }
        function close() { showing = false }
        readonly property bool opened: showing

        visible: showing || fadeAnim.running
        opacity: showing ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.InOutQuad
            }
        }

        flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        color: "transparent"

        readonly property real thumbWidth: windowIds.length <= 1
            ? Kirigami.Units.gridUnit * 16
            : Kirigami.Units.gridUnit * 12

        width: Math.max(Kirigami.Units.gridUnit * 8,
            windowIds.length * thumbWidth
            + Math.max(0, windowIds.length - 1) * Kirigami.Units.smallSpacing
            + 2 * Kirigami.Units.smallSpacing)
        height: popupContent.implicitHeight + 2 * Kirigami.Units.smallSpacing

        // Position above the hovered dock icon, in global coordinates
        x: {
            if (!targetDelegate) return 0
            var delegateGlobal = targetDelegate.mapToGlobal(0, 0)
            var win = targetDelegate.Window.window
            var scrW = win && win.screen ? win.screen.width : Screen.width
            return Math.max(0, Math.min(scrW - width, delegateGlobal.x + (targetDelegate.width - width) / 2))
        }
        y: {
            if (!targetDelegate) return 0
            var delegateGlobal = targetDelegate.mapToGlobal(0, 0)
            var win = targetDelegate.Window.window
            var scrH = win && win.screen ? win.screen.height : Screen.height
            return Math.max(0, Math.min(scrH - height, delegateGlobal.y - height - Kirigami.Units.smallSpacing))
        }

        onShowingChanged: {
            if (!showing && !fadeAnim.running) {
                windowIds = []
                targetDelegate = null
                taskIndex = -1
                isGroup = false
            }
        }

        Connections {
            target: fadeAnim
            function onRunningChanged() {
                if (!fadeAnim.running && !thumbnailPopup.showing) {
                    thumbnailPopup.windowIds = []
                    thumbnailPopup.targetDelegate = null
                    thumbnailPopup.taskIndex = -1
                    thumbnailPopup.isGroup = false
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.rgba(
                Kirigami.Theme.textColor.r,
                Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.2)
            border.width: 1
            radius: Kirigami.Units.cornerRadius

            // HoverHandler for popup-level hover tracking (does not
            // consume mouse events, so clicks still reach delegates).
            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: {
                    thumbnailPopup.popupHovered = hovered
                    if (hovered) {
                        thumbnailHideTimer.stop()
                    } else if (root.hoveredTaskIndex < 0) {
                        thumbnailHideTimer.restart()
                    }
                }
            }

            Row {
                id: popupContent
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: thumbnailPopup.windowIds.length

                    delegate: MouseArea {
                        id: thumbEntry
                        width: thumbnailPopup.thumbWidth
                        height: thumbColumn.implicitHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        readonly property string childUuid: thumbnailPopup.windowIds[index] || ""
                        readonly property string childTitle: {
                            if (!thumbnailPopup.isGroup)
                                return tasksModel.data(tasksModel.makeModelIndex(thumbnailPopup.taskIndex), 0) || ""
                            return tasksModel.data(tasksModel.makeModelIndex(thumbnailPopup.taskIndex, index), 0) || ""
                        }

                        onClicked: {
                            var idx = thumbnailPopup.isGroup
                                ? tasksModel.makeModelIndex(thumbnailPopup.taskIndex, index)
                                : tasksModel.makeModelIndex(thumbnailPopup.taskIndex)
                            tasksModel.requestActivate(idx)
                            thumbnailPopup.close()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: thumbEntry.containsMouse
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                          Kirigami.Theme.highlightColor.g,
                                          Kirigami.Theme.highlightColor.b, 0.15)
                                : "transparent"
                        }

                        Column {
                            id: thumbColumn
                            width: parent.width
                            spacing: Kirigami.Units.smallSpacing

                            Item {
                                width: parent.width
                                height: width * 9 / 16

                                Loader {
                                    id: thumbPipeWireLoader
                                    active: thumbnailPopup.visible
                                        && thumbEntry.childUuid !== ""
                                    anchors.fill: parent
                                    sourceComponent: PipeWireThumbnail {
                                        windowUuid: thumbEntry.childUuid
                                    }
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.huge
                                    height: width
                                    source: thumbnailPopup.targetDelegate
                                        ? thumbnailPopup.targetDelegate.model.decoration
                                        : ""
                                    visible: !thumbPipeWireLoader.item
                                        || !thumbPipeWireLoader.item.hasThumbnail
                                }

                                MouseArea {
                                    id: closeButton
                                    width: Kirigami.Units.iconSizes.small
                                    height: width
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    z: 1
                                    visible: thumbEntry.containsMouse
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        var idx = thumbnailPopup.isGroup
                                            ? tasksModel.makeModelIndex(thumbnailPopup.taskIndex, index)
                                            : tasksModel.makeModelIndex(thumbnailPopup.taskIndex)
                                        tasksModel.requestClose(idx)
                                        if (thumbnailPopup.windowIds.length <= 1) {
                                            thumbnailPopup.close()
                                        }
                                    }

                                    Kirigami.Icon {
                                        anchors.fill: parent
                                        source: "window-close"
                                    }
                                }
                            }

                            PC3.Label {
                                width: parent.width
                                text: thumbEntry.childTitle
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                maximumLineCount: 1
                            }
                        }
                    }
                }
            }
        }
    }

    // Separator between pinned favourites and running tasks
    Rectangle {
        id: dockSpacer
        visible: root.showSpacer
        x: (repeater.count - root.totalItemCount / 2) * root.dockCellWidth + root.dockCenterX - width / 2
        y: parent.height * 0.2
        width: Math.round(Kirigami.Units.devicePixelRatio)
        height: parent.height * 0.6
        color: Kirigami.Theme.textColor
        opacity: 0.4
    }

    PlaceholderDelegate {
        id: taskPinPlaceholder
        visible: root.taskPinCanDrop
        folio: root.folio
        width: root.dockCellWidth
        height: root.dockCellHeight
        x: root.favouriteBaseX(root.taskPinTargetIndex)
        y: (parent.height - height) / 2
        z: 1
    }

    Repeater {
        id: taskRepeater
        model: root.convergenceMode ? tasksModel : null

        delegate: Item {
            id: taskDelegate

            required property int index
            required property var model

            activeFocusOnTab: root.convergenceMode

            readonly property bool isLocationBottom: folio.HomeScreenState.favouritesBarLocation === Folio.HomeScreenState.Bottom
            readonly property string taskStorageId: root.runningTaskStorageId(taskDelegate.model)

            Accessible.role: Accessible.Button
            Accessible.name: taskDelegate.model.display || ""
            Accessible.onPressAction: taskDelegate.activateTask()

            function activateTask() {
                var winIds = taskDelegate.model.WinIdList
                if (winIds && winIds.length > 1) {
                    if (thumbnailPopup.opened && thumbnailPopup.taskIndex === taskDelegate.index) {
                        thumbnailPopup.close()
                    } else {
                        thumbnailPopup.targetDelegate = taskDelegate
                        thumbnailPopup.taskIndex = taskDelegate.index
                        thumbnailPopup.windowIds = winIds
                        thumbnailPopup.isGroup = taskDelegate.model.IsGroupParent === true
                        thumbnailPopup.open()
                    }
                } else {
                    thumbnailPopup.close()
                    tasksModel.requestActivate(tasksModel.makeModelIndex(taskDelegate.index))
                }
            }

            Keys.onReturnPressed: taskDelegate.activateTask()
            Keys.onEnterPressed: taskDelegate.activateTask()
            Keys.onSpacePressed: taskDelegate.activateTask()
            Keys.onLeftPressed: {
                let prev = taskRepeater.itemAt(taskDelegate.index - 1)
                if (prev) { prev.forceActiveFocus(); return }
                let lastFav = repeater.itemAt(repeater.count - 1)
                if (lastFav) { lastFav.keyboardFocus(); return }
                homeButton.forceActiveFocus()
            }
            Keys.onRightPressed: {
                let next = taskRepeater.itemAt(taskDelegate.index + 1)
                if (next) { next.forceActiveFocus(); return }
                overviewButton.forceActiveFocus()
            }

            // Position after all favourites
            property double fromCenterValue: (repeater.count + taskDelegate.index) - (root.totalItemCount / 2)
            Behavior on fromCenterValue {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad; }
            }

            readonly property int centerPosition: (isLocationBottom ? root.dockCellWidth : root.dockCellHeight) * fromCenterValue

            x: isLocationBottom ? root.taskBaseX(taskDelegate.index) + (root.taskPinDragIndex === taskDelegate.index ? root.taskPinDragOffset : 0) : (parent.width - width) / 2
            y: isLocationBottom ? (parent.height - height) / 2 : parent.height / 2 - centerPosition - root.dockCellHeight
            z: root.taskPinDragIndex === taskDelegate.index ? 2 : 0

            implicitWidth: root.dockCellWidth
            implicitHeight: root.dockCellHeight
            width: root.dockCellWidth
            height: root.dockCellHeight

            // Hover highlight background
            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: taskMouseArea.containsPress
                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                    : (taskMouseArea.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1) : "transparent")
            }

            KeyboardHighlight {
                anchors.fill: parent
                visible: taskDelegate.activeFocus
            }

            // Task icon
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.6
                height: width
                source: taskDelegate.model.decoration
                active: taskMouseArea.containsMouse
            }

            DragHandler {
                id: taskDragHandler
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                enabled: root.convergenceMode && taskDelegate.isLocationBottom && !folio.FolioSettings.lockLayout && taskDelegate.taskStorageId !== "" && !folio.FavouritesModel.containsApplication(taskDelegate.taskStorageId)

                onActiveChanged: {
                    if (active) {
                        thumbnailPopup.close()
                        thumbnailShowTimer.stop()
                        thumbnailHideTimer.stop()
                        root.hoveredTaskIndex = -1
                        root.taskPinDragIndex = taskDelegate.index
                        root.taskPinDragOffset = 0
                        root.taskPinTargetIndex = -1
                        root.taskPinStorageId = taskDelegate.taskStorageId
                    } else if (root.taskPinDragIndex === taskDelegate.index) {
                        if (root.taskPinCanDrop) {
                            folio.FavouritesModel.addApplicationAt(root.taskPinTargetIndex, root.taskPinStorageId)
                        }
                        root.clearTaskPinDrag()
                    }
                }

                onTranslationChanged: {
                    if (root.taskPinDragIndex === taskDelegate.index) {
                        root.taskPinDragOffset = translation.x
                        root.updateTaskPinTarget()
                    }
                }

                onCanceled: {
                    if (root.taskPinDragIndex === taskDelegate.index) {
                        root.clearTaskPinDrag()
                    }
                }
            }

            // Window indicator dots (one per sibling window of the same app)
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
                spacing: Kirigami.Units.smallSpacing / 2

                Repeater {
                    model: {
                        var ids = taskDelegate.model.WinIdList
                        return Math.max(1, ids ? ids.length : 0)
                    }

                    Rectangle {
                        width: Kirigami.Units.smallSpacing * 1.5
                        height: width
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        opacity: taskDelegate.model.IsActive === true ? 1.0 : 0.4
                    }
                }
            }

            // Click to activate, middle-click to close, hover for thumbnail preview
            MouseArea {
                id: taskMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.convergenceMode ? Qt.PointingHandCursor : Qt.ArrowCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        thumbnailPopup.close()
                        tasksModel.requestClose(tasksModel.makeModelIndex(taskDelegate.index));
                        return
                    }
                    if (mouse.button === Qt.RightButton) {
                        thumbnailPopup.close()
                        thumbnailShowTimer.stop()
                        taskContextMenu.open();
                    } else {
                        taskDelegate.activateTask()
                    }
                }
                onContainsMouseChanged: {
                    if (containsMouse) {
                        thumbnailHideTimer.stop()
                        thumbnailPopup.targetDelegate = taskDelegate
                        thumbnailPopup.taskIndex = taskDelegate.index
                        var winIds = taskDelegate.model.WinIdList
                        thumbnailPopup.windowIds = winIds ? winIds : []
                        thumbnailPopup.isGroup = taskDelegate.model.IsGroupParent === true
                        root.hoveredTaskIndex = taskDelegate.index
                        if (!thumbnailPopup.opened) {
                            thumbnailShowTimer.restart()
                        }
                    } else {
                        root.hoveredTaskIndex = -1
                        if (!thumbnailPopup.popupHovered) {
                            thumbnailShowTimer.stop()
                            thumbnailHideTimer.restart()
                        }
                    }
                }
            }

            PC3.Menu {
                id: taskContextMenu
                popupType: T.Popup.Window

                PC3.MenuItem {
                    icon.name: "window-pin"
                    text: i18n("Pin to Dock")
                    // repeater.count dependency forces re-evaluation when favourites change
                    visible: taskDelegate.taskStorageId !== "" && repeater.count >= 0 && !folio.FavouritesModel.containsApplication(taskDelegate.taskStorageId)
                    enabled: !folio.FolioSettings.lockLayout
                    onClicked: folio.FavouritesModel.addApplication(taskDelegate.taskStorageId)
                }
                PC3.MenuItem {
                    icon.name: taskDelegate.model.IsMinimized ? "window-restore" : "window-minimize"
                    text: taskDelegate.model.IsMinimized ? i18n("Restore") : i18n("Minimize")
                    onClicked: tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: taskDelegate.model.IsMaximized ? "window-restore" : "window-maximize"
                    text: taskDelegate.model.IsMaximized ? i18n("Restore") : i18n("Maximize")
                    visible: taskDelegate.model.IsGroupParent !== true
                    onClicked: tasksModel.requestToggleMaximized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "window-close"
                    text: {
                        var ids = taskDelegate.model.WinIdList
                        return (ids && ids.length > 1) ? i18n("Close All") : i18n("Close")
                    }
                    onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(taskDelegate.index))
                }
            }
        }
    }
}
