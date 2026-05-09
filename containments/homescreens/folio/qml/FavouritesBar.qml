// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Layouts 1.1
import QtCore
import Qt.labs.folderlistmodel

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
    property bool suppressRunningTasks: false

    signal delegateDragRequested(var item)

    // Convergence mode: show running apps alongside favourites
    readonly property bool convergenceMode: ShellSettings.Settings.convergenceModeEnabled
    readonly property bool showRunningTasks: convergenceMode && !suppressRunningTasks
    readonly property int totalItemCount: repeater.count + (showRunningTasks ? taskRepeater.count : 0)

    // In convergence mode, size icons to fit the dock bar instead of using page grid cells
    property real dockCellWidth: convergenceMode ? root.height : folio.HomeScreenState.pageCellWidth
    property real dockCellHeight: convergenceMode ? root.height : folio.HomeScreenState.pageCellHeight
    Behavior on dockCellWidth { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }
    Behavior on dockCellHeight { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }

    // Navigation buttons width (used to offset center positioning)
    property real navButtonWidth: convergenceMode ? root.height : 0
    property real dockItemInset: convergenceMode ? Math.max(2, Kirigami.Units.smallSpacing / 2) : 0
    property real dockIconSize: Math.min(root.height * 0.56, Kirigami.Units.iconSizes.large)
    Behavior on navButtonWidth { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }
    Behavior on dockItemInset { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }
    Behavior on dockIconSize { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }

    function dockItemColor(pressed, hovered, active) {
        if (pressed) {
            return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.18)
        }
        if (active) {
            return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, hovered ? 0.18 : 0.12)
        }
        if (hovered) {
            return Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        }
        return "transparent"
    }

    // Visible spacer between pinned favourites and running tasks
    readonly property bool showSpacer: showRunningTasks && repeater.count > 0 && taskRepeater.count > 0
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

    // Virtual desktop pager (convergence mode, 2+ desktops)
    readonly property bool showPager: convergenceMode && virtualDesktopInfo.numberOfDesktops > 1
    property real pagerButtonWidth: showPager ? Math.min(root.height, Kirigami.Units.gridUnit * 2.5) : 0
    readonly property int pagerLeftCount: showPager ? Math.ceil(virtualDesktopInfo.numberOfDesktops / 2) : 0
    readonly property int pagerRightCount: showPager ? virtualDesktopInfo.numberOfDesktops - pagerLeftCount : 0
    property real trashButtonWidth: convergenceMode ? root.height : 0
    property real searchButtonWidth: convergenceMode ? root.height : 0
    readonly property real leftControlsWidth: convergenceMode ? navButtonWidth + pagerLeftCount * pagerButtonWidth : 0
    readonly property real rightControlsWidth: convergenceMode ? navButtonWidth + searchButtonWidth + trashButtonWidth + pagerRightCount * pagerButtonWidth : 0
    readonly property real dockCenterX: convergenceMode
        ? leftControlsWidth + (root.width - leftControlsWidth - rightControlsWidth) / 2
        : root.width / 2
    Behavior on pagerButtonWidth { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }
    Behavior on trashButtonWidth { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }
    Behavior on searchButtonWidth { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutCubic } }

    function pagerDesktopName(index) {
        let names = virtualDesktopInfo.desktopNames
        if (names && index < names.length && String(names[index]).length > 0)
            return String(names[index])
        return i18n("Desktop %1", index + 1)
    }

    function pagerDesktopNameForId(desktopId) {
        let ids = virtualDesktopInfo.desktopIds
        if (!ids) {
            return ""
        }
        for (let i = 0; i < ids.length; ++i) {
            if (String(ids[i]) === String(desktopId)) {
                return root.pagerDesktopName(i)
            }
        }
        return ""
    }

    function menuDesktopIds(isOnAllDesktops) {
        let ids = virtualDesktopInfo.desktopIds
        if (!ids || ids.length <= 1) {
            return []
        }

        let result = []
        for (let i = 0; i < ids.length; ++i) {
            if (isOnAllDesktops || String(ids[i]) !== String(virtualDesktopInfo.currentDesktop)) {
                result.push(ids[i])
            }
        }
        return result
    }

    // Returns the desktop ID of the pager button under screen-space x, or ""
    function pagerButtonDesktopAt(x) {
        if (!showPager) return ""
        let ids = virtualDesktopInfo.desktopIds
        for (let i = 0; i < pagerLeftCount; ++i) {
            let bx = navButtonWidth + i * pagerButtonWidth
            if (x >= bx && x < bx + pagerButtonWidth)
                return (ids && i < ids.length) ? String(ids[i]) : ""
        }
        for (let i = 0; i < pagerRightCount; ++i) {
            let bx = root.width - navButtonWidth - root.searchButtonWidth - root.trashButtonWidth - (pagerRightCount - i) * pagerButtonWidth
            if (x >= bx && x < bx + pagerButtonWidth) {
                let di = pagerLeftCount + i
                return (ids && di < ids.length) ? String(ids[di]) : ""
            }
        }
        return ""
    }

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
        visible: root.convergenceMode || opacity > 0
        enabled: root.convergenceMode
        opacity: root.convergenceMode ? 1 : 0
        activeFocusOnTab: root.convergenceMode
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: "transparent"

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

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
            searchButton.forceActiveFocus()
        }

        KeyboardHighlight {
            anchors.fill: parent
            visible: homeButton.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.dockItemInset
            radius: Kirigami.Units.cornerRadius
            color: root.dockItemColor(homeMouseArea.containsPress, homeMouseArea.containsMouse, false)

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.dockIconSize
            height: width
            source: "start-here-shift"
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
        visible: root.convergenceMode || opacity > 0
        enabled: root.convergenceMode
        opacity: root.convergenceMode ? 1 : 0
        activeFocusOnTab: root.convergenceMode
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.navButtonWidth
        color: "transparent"

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        Accessible.role: Accessible.Button
        Accessible.name: i18n("Overview")
        Accessible.onPressAction: root.folio.triggerOverview()

        Keys.onReturnPressed: root.folio.triggerOverview()
        Keys.onEnterPressed: root.folio.triggerOverview()
        Keys.onSpacePressed: root.folio.triggerOverview()
        Keys.onLeftPressed: {
            searchButton.forceActiveFocus()
        }

        KeyboardHighlight {
            anchors.fill: parent
            visible: overviewButton.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.dockItemInset
            radius: Kirigami.Units.cornerRadius
            color: root.dockItemColor(overviewMouseArea.containsPress, overviewMouseArea.containsMouse, false)

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.dockIconSize
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

    // Search button (convergence mode, immediately left of Overview)
    Rectangle {
        id: searchButton
        visible: root.convergenceMode || opacity > 0
        enabled: root.convergenceMode
        opacity: root.convergenceMode ? 1 : 0
        activeFocusOnTab: root.convergenceMode
        x: root.width - root.navButtonWidth - root.searchButtonWidth
        y: 0
        width: root.searchButtonWidth
        height: root.height
        color: "transparent"

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        Accessible.role: Accessible.Button
        Accessible.name: i18n("Search")
        Accessible.onPressAction: root.folio.HomeScreenState.openSearchWidget()

        Keys.onReturnPressed: root.folio.HomeScreenState.openSearchWidget()
        Keys.onEnterPressed: root.folio.HomeScreenState.openSearchWidget()
        Keys.onSpacePressed: root.folio.HomeScreenState.openSearchWidget()
        Keys.onLeftPressed: {
            let lastTask = taskRepeater.itemAt(taskRepeater.count - 1)
            if (lastTask) { lastTask.forceActiveFocus(); return }
            let lastFav = repeater.itemAt(repeater.count - 1)
            if (lastFav) { lastFav.keyboardFocus(); return }
            homeButton.forceActiveFocus()
        }
        Keys.onRightPressed: overviewButton.forceActiveFocus()

        KeyboardHighlight {
            anchors.fill: parent
            visible: searchButton.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.dockItemInset
            radius: Kirigami.Units.cornerRadius
            color: root.dockItemColor(searchMouseArea.containsPress, searchMouseArea.containsMouse, false)

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.dockIconSize
            height: width
            source: "search"
            active: searchMouseArea.containsMouse
        }

        PC3.ToolTip {
            visible: searchMouseArea.containsMouse
            text: i18n("Search")
        }

        MouseArea {
            id: searchMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.convergenceMode ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.folio.HomeScreenState.openSearchWidget()
        }
    }

    // ---- Virtual desktop pager: left wing (desktops 1 .. ceil(N/2)) ----
    Repeater {
        id: leftPagerRepeater
        model: root.pagerLeftCount

        delegate: Item {
            id: leftDesktopBtn
            required property int index

            readonly property string desktopId: {
                let ids = virtualDesktopInfo.desktopIds
                return (ids && index < ids.length) ? String(ids[index]) : ""
            }
            readonly property bool isCurrent: desktopId !== "" && String(desktopId) === String(virtualDesktopInfo.currentDesktop)
            readonly property bool isDragTarget: {
                if (root.taskPinDragIndex < 0) return false
                let cx = root.taskBaseX(root.taskPinDragIndex) + root.dockCellWidth / 2 + root.taskPinDragOffset
                return root.pagerButtonDesktopAt(cx) === desktopId
            }

            x: root.navButtonWidth + index * root.pagerButtonWidth
            y: 0
            width: root.pagerButtonWidth
            height: root.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.dockItemInset
                radius: Kirigami.Units.cornerRadius
                color: leftDesktopBtn.isCurrent || leftDesktopBtn.isDragTarget
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                              leftPagerHover.containsMouse || leftDesktopBtn.isDragTarget ? 0.25 : 0.18)
                    : root.dockItemColor(leftPagerHover.containsPress, leftPagerHover.containsMouse, false)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }

            PC3.Label {
                anchors.centerIn: parent
                text: (leftDesktopBtn.index + 1).toString()
                color: leftDesktopBtn.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                font.pixelSize: Math.round(parent.height * 0.3)
                font.bold: leftDesktopBtn.isCurrent
            }

            PC3.ToolTip {
                visible: leftPagerHover.containsMouse
                text: root.pagerDesktopName(leftDesktopBtn.index)
            }

            MouseArea {
                id: leftPagerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (leftDesktopBtn.desktopId)
                        root.folio.activateVirtualDesktop(leftDesktopBtn.desktopId)
                }
            }
        }
    }

    // ---- Virtual desktop pager: right wing (desktops ceil(N/2)+1 .. N) ----
    Repeater {
        id: rightPagerRepeater
        model: root.pagerRightCount

        delegate: Item {
            id: rightDesktopBtn
            required property int index

            readonly property int desktopIndex: root.pagerLeftCount + index
            readonly property string desktopId: {
                let ids = virtualDesktopInfo.desktopIds
                return (ids && desktopIndex < ids.length) ? String(ids[desktopIndex]) : ""
            }
            readonly property bool isCurrent: desktopId !== "" && String(desktopId) === String(virtualDesktopInfo.currentDesktop)
            readonly property bool isDragTarget: {
                if (root.taskPinDragIndex < 0) return false
                let cx = root.taskBaseX(root.taskPinDragIndex) + root.dockCellWidth / 2 + root.taskPinDragOffset
                return root.pagerButtonDesktopAt(cx) === desktopId
            }

            x: root.width - root.navButtonWidth - root.searchButtonWidth - root.trashButtonWidth - (root.pagerRightCount - index) * root.pagerButtonWidth
            y: 0
            width: root.pagerButtonWidth
            height: root.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.dockItemInset
                radius: Kirigami.Units.cornerRadius
                color: rightDesktopBtn.isCurrent || rightDesktopBtn.isDragTarget
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b,
                              rightPagerHover.containsMouse || rightDesktopBtn.isDragTarget ? 0.25 : 0.18)
                    : root.dockItemColor(rightPagerHover.containsPress, rightPagerHover.containsMouse, false)
                Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
            }

            PC3.Label {
                anchors.centerIn: parent
                text: (rightDesktopBtn.desktopIndex + 1).toString()
                color: rightDesktopBtn.isCurrent ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                font.pixelSize: Math.round(parent.height * 0.3)
                font.bold: rightDesktopBtn.isCurrent
            }

            PC3.ToolTip {
                visible: rightPagerHover.containsMouse
                text: root.pagerDesktopName(rightDesktopBtn.desktopIndex)
            }

            MouseArea {
                id: rightPagerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (rightDesktopBtn.desktopId)
                        root.folio.activateVirtualDesktop(rightDesktopBtn.desktopId)
                }
            }
        }
    }

    // ---- Trash button (convergence mode, sits between the right pager wing and the Overview button) ----

    // Watches ~/.local/share/Trash/files to detect empty/full state.
    // FolderListModel reacts to directory changes automatically.
    FolderListModel {
        id: trashFilesModel
        folder: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/Trash/files"
        showFiles: true
        showDirs: true
        showDotAndDotDot: false
    }

    // Confirmation dialog for "Empty Trash" — parented to the homescreen so it
    // is sized correctly and floats above all dock content.
    Loader {
        id: emptyTrashDialogLoader
        parent: root.homeScreen
        anchors.fill: parent
        active: false

        function open() {
            active = true;
            item.open();
        }

        sourceComponent: Kirigami.PromptDialog {
            title: i18n("Empty Trash")
            subtitle: i18n("Permanently delete all items in the trash? This action cannot be undone.")
            standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.Cancel
            onAccepted: root.folio.emptyTrash()
            onClosed: emptyTrashDialogLoader.active = false
        }
    }

    Rectangle {
        id: trashButton
        visible: root.convergenceMode || opacity > 0
        enabled: root.convergenceMode
        opacity: root.convergenceMode ? 1 : 0
        activeFocusOnTab: root.convergenceMode
        x: root.width - root.navButtonWidth - root.searchButtonWidth - root.trashButtonWidth
        y: 0
        width: root.trashButtonWidth
        height: root.height
        color: "transparent"

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        Accessible.role: Accessible.Button
        Accessible.name: i18n("Trash")
        Accessible.onPressAction: Qt.openUrlExternally("trash:/")

        Keys.onReturnPressed: Qt.openUrlExternally("trash:/")
        Keys.onEnterPressed:  Qt.openUrlExternally("trash:/")
        Keys.onSpacePressed:  Qt.openUrlExternally("trash:/")

        KeyboardHighlight {
            anchors.fill: parent
            visible: trashButton.activeFocus
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: root.dockItemInset
            radius: Kirigami.Units.cornerRadius
            color: root.dockItemColor(trashMouseArea.containsPress, trashMouseArea.containsMouse, false)
            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.dockIconSize
            height: width
            source: trashFilesModel.count > 0 ? "user-trash-full" : "user-trash"
            active: trashMouseArea.containsMouse
        }

        PC3.ToolTip {
            visible: trashMouseArea.containsMouse
            text: trashFilesModel.count > 0
                ? i18np("Trash — 1 item", "Trash — %1 items", trashFilesModel.count)
                : i18n("Trash")
        }

        MouseArea {
            id: trashMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    trashContextMenu.open()
                } else {
                    Qt.openUrlExternally("trash:/")
                }
            }
        }

        PC3.Menu {
            id: trashContextMenu
            popupType: T.Popup.Window

            PC3.MenuItem {
                icon.name: "folder-open"
                text: i18n("Open Trash")
                onTriggered: Qt.openUrlExternally("trash:/")
            }
            PC3.MenuItem {
                icon.name: "trash-empty"
                text: i18n("Empty Trash")
                enabled: trashFilesModel.count > 0
                onTriggered: emptyTrashDialogLoader.open()
            }
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
        if (mouse.button === Qt.RightButton) {
            if (convergenceMode) {
                root.homeScreen.showDesktopContextMenu();
            } else {
                folio.HomeScreenState.openSettingsView();
            }
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
                                searchButton.forceActiveFocus();
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
                    shadow: !root.convergenceMode

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
                    shadow: !root.convergenceMode
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
            var win = root.Window.window
            var screenLeft = win && win.screen ? win.screen.virtualX : 0
            var screenRight = screenLeft + (win && win.screen ? win.screen.width : Screen.width)
            // The dock window is full-width, anchored to the screen's left edge.
            // targetDelegate.x is dock-local, so the global center of the icon is:
            var globalCenter = screenLeft + targetDelegate.x + targetDelegate.width / 2
            return Math.max(screenLeft, Math.min(screenRight - width, globalCenter - width / 2))
        }
        y: {
            var win = root.Window.window
            var screenTop = win && win.screen ? win.screen.virtualY : 0
            var screenBottom = screenTop + (win && win.screen ? win.screen.height : Screen.height)
            // Dock is bottom-anchored; its top edge is at screenBottom - dock window height.
            var dockTop = screenBottom - (win ? win.height : root.height)
            return Math.max(screenTop, dockTop - height - Kirigami.Units.smallSpacing)
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
        y: parent.height * 0.28
        width: Math.round(Kirigami.Units.devicePixelRatio)
        height: parent.height * 0.44
        color: Kirigami.Theme.textColor
        opacity: 0.22
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
        model: root.showRunningTasks ? tasksModel : null

        delegate: Item {
            id: taskDelegate

            required property int index
            required property var model

            activeFocusOnTab: root.convergenceMode

            readonly property bool isLocationBottom: folio.HomeScreenState.favouritesBarLocation === Folio.HomeScreenState.Bottom
            readonly property string taskStorageId: root.runningTaskStorageId(taskDelegate.model)
            readonly property bool isGroupParent: taskDelegate.model.IsGroupParent === true
            readonly property bool dynamicTilingActive: root.convergenceMode && ShellSettings.Settings.dynamicTilingEnabled
            readonly property bool showFreeGeometryActions: !taskDelegate.isGroupParent && !taskDelegate.dynamicTilingActive
            readonly property bool canChangeVirtualDesktops: taskDelegate.model.IsVirtualDesktopsChangeable === true

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
                searchButton.forceActiveFocus()
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
                anchors.margins: root.dockItemInset
                radius: Kirigami.Units.cornerRadius
                color: root.dockItemColor(taskMouseArea.containsPress, taskMouseArea.containsMouse, taskDelegate.model.IsActive === true)

                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                }
            }

            KeyboardHighlight {
                anchors.fill: parent
                visible: taskDelegate.activeFocus
            }

            // Task icon
            Kirigami.Icon {
                anchors.centerIn: parent
                width: root.dockIconSize
                height: width
                source: taskDelegate.model.decoration
                active: taskMouseArea.containsMouse
            }

            DragHandler {
                id: taskDragHandler
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                // Enable for unpinned tasks (pin-to-dock drag) and for ALL tasks
                // when the pager is showing so windows can be dragged to a desktop button.
                enabled: root.convergenceMode && taskDelegate.isLocationBottom && !folio.FolioSettings.lockLayout && taskDelegate.taskStorageId !== "" && (root.showPager || !folio.FavouritesModel.containsApplication(taskDelegate.taskStorageId))

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
                        // If released over a pager button, move the window to that desktop.
                        let finalCenterX = root.taskBaseX(taskDelegate.index) + root.dockCellWidth / 2 + root.taskPinDragOffset
                        let pagerDesktop = root.pagerButtonDesktopAt(finalCenterX)
                        if (pagerDesktop && taskDelegate.model.IsVirtualDesktopsChangeable === true) {
                            tasksModel.requestVirtualDesktops(tasksModel.makeModelIndex(taskDelegate.index), [pagerDesktop])
                        } else if (root.taskPinCanDrop && !folio.FavouritesModel.containsApplication(root.taskPinStorageId)) {
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
                anchors.bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2

                Repeater {
                    model: {
                        var ids = taskDelegate.model.WinIdList
                        return Math.max(1, ids ? ids.length : 0)
                    }

                    Rectangle {
                        width: taskDelegate.model.IsActive === true ? Kirigami.Units.smallSpacing * 3 : Kirigami.Units.smallSpacing * 1.5
                        height: Math.max(2, Math.round(Kirigami.Units.devicePixelRatio))
                        radius: height / 2
                        color: Kirigami.Theme.highlightColor
                        opacity: taskDelegate.model.IsActive === true ? 1.0 : 0.45

                        Behavior on width {
                            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                        }
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
                    icon.name: "window-new"
                    text: i18n("Open New Window")
                    visible: taskDelegate.model.CanLaunchNewInstance === true
                    height: visible ? implicitHeight : 0
                    onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "window-pin"
                    text: i18n("Pin to Dock")
                    // repeater.count dependency forces re-evaluation when favourites change
                    visible: taskDelegate.taskStorageId !== "" && repeater.count >= 0 && !folio.FavouritesModel.containsApplication(taskDelegate.taskStorageId)
                    height: visible ? implicitHeight : 0
                    enabled: !folio.FolioSettings.lockLayout
                    onClicked: folio.FavouritesModel.addApplication(taskDelegate.taskStorageId)
                }

                Controls.MenuSeparator {
                    visible: taskDelegate.model.CanLaunchNewInstance === true
                             || (taskDelegate.taskStorageId !== "" && repeater.count >= 0 && !folio.FavouritesModel.containsApplication(taskDelegate.taskStorageId))
                    height: visible ? implicitHeight : 0
                }

                PC3.MenuItem {
                    icon.name: "transform-move"
                    text: i18n("Move")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    enabled: taskDelegate.model.IsMovable === true
                    onClicked: tasksModel.requestMove(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "transform-scale"
                    text: i18n("Resize")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    enabled: taskDelegate.model.IsResizable === true
                    onClicked: tasksModel.requestResize(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: taskDelegate.model.IsMinimized ? "window-restore" : "window-minimize"
                    text: taskDelegate.model.IsMinimized ? i18n("Restore") : i18n("Minimize")
                    enabled: taskDelegate.model.IsMinimizable === true
                    onClicked: tasksModel.requestToggleMinimized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: taskDelegate.model.IsMaximized ? "window-restore" : "window-maximize"
                    text: taskDelegate.model.IsMaximized ? i18n("Restore") : i18n("Maximize")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    enabled: taskDelegate.model.IsMaximizable === true
                    onClicked: tasksModel.requestToggleMaximized(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "window-keep-above"
                    text: taskDelegate.model.IsKeepAbove ? i18n("Do Not Keep Above Others") : i18n("Keep Above Others")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    onClicked: tasksModel.requestToggleKeepAbove(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "window-keep-below"
                    text: taskDelegate.model.IsKeepBelow ? i18n("Do Not Keep Below Others") : i18n("Keep Below Others")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    onClicked: tasksModel.requestToggleKeepBelow(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "view-fullscreen"
                    text: taskDelegate.model.IsFullScreen ? i18n("Leave Fullscreen") : i18n("Fullscreen")
                    visible: taskDelegate.showFreeGeometryActions
                    height: visible ? implicitHeight : 0
                    enabled: taskDelegate.model.IsFullScreenable === true
                    onClicked: tasksModel.requestToggleFullScreen(tasksModel.makeModelIndex(taskDelegate.index))
                }
                PC3.MenuItem {
                    icon.name: "window-close"
                    text: {
                        var ids = taskDelegate.model.WinIdList
                        return (ids && ids.length > 1) ? i18n("Close All") : i18n("Close")
                    }
                    enabled: taskDelegate.model.IsClosable === true
                    onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(taskDelegate.index))
                }

                Controls.MenuSeparator {
                    visible: taskDelegate.canChangeVirtualDesktops
                    height: visible ? implicitHeight : 0
                }

                PC3.MenuItem {
                    icon.name: "virtual-desktops"
                    text: taskDelegate.model.IsOnAllVirtualDesktops ? i18n("Show Only on Current Desktop") : i18n("Show on All Desktops")
                    visible: taskDelegate.canChangeVirtualDesktops && virtualDesktopInfo.numberOfDesktops > 1
                    height: visible ? implicitHeight : 0
                    onClicked: tasksModel.requestVirtualDesktops(tasksModel.makeModelIndex(taskDelegate.index),
                        taskDelegate.model.IsOnAllVirtualDesktops ? [virtualDesktopInfo.currentDesktop] : [])
                }

                Instantiator {
                    model: root.showPager && taskDelegate.canChangeVirtualDesktops ? root.menuDesktopIds(taskDelegate.model.IsOnAllVirtualDesktops === true) : []
                    delegate: PC3.MenuItem {
                        required property var modelData
                        text: i18n("Move to %1", root.pagerDesktopNameForId(modelData))
                        onTriggered: tasksModel.requestVirtualDesktops(
                            tasksModel.makeModelIndex(taskDelegate.index), [modelData])
                    }
                    onObjectAdded: (idx, obj) => taskContextMenu.insertItem(taskContextMenu.count, obj)
                    onObjectRemoved: (idx, obj) => taskContextMenu.removeItem(obj)
                }
                PC3.MenuItem {
                    icon.name: "list-add"
                    text: i18n("Move to New Desktop")
                    visible: taskDelegate.canChangeVirtualDesktops
                    height: visible ? implicitHeight : 0
                    onClicked: tasksModel.requestNewVirtualDesktop(tasksModel.makeModelIndex(taskDelegate.index))
                }
            }
        }
    }
}
