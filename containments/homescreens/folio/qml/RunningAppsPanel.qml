// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3
import org.kde.taskmanager as TaskManager

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

Item {
    id: root

    required property var folio

    readonly property bool hasTasks: allTasksModel.count > 0
    property bool sortByName: false
    property int dragTargetDesktopIndex: -1
    property string pendingMoveTaskKey: ""
    property string pendingMoveTargetName: ""

    signal taskActivated()

    function taskStorageId(taskModel) {
        var id = taskModel ? taskModel.AppId || "" : ""
        if (id && !id.endsWith(".desktop")) {
            id += ".desktop"
        }
        return id
    }

    function taskKey(taskModel) {
        const winIds = taskModel && taskModel.WinIdList ? taskModel.WinIdList : []
        if (winIds.length > 0) {
            var key = ""
            for (var i = 0; i < winIds.length; ++i) {
                key += String(winIds[i]) + "|"
            }
            return key
        }

        return String(taskModel ? taskModel.AppId || "" : "") + "|" + String(taskModel ? taskModel.display || "" : "")
    }

    function markTaskMove(taskKey, desktopIndex) {
        pendingMoveTaskKey = taskKey
        pendingMoveTargetName = desktopName(desktopIndex)
        pendingMoveResetTimer.restart()
    }

    function mixColor(base, overlay, ratio) {
        return Qt.rgba(
            base.r + (overlay.r - base.r) * ratio,
            base.g + (overlay.g - base.g) * ratio,
            base.b + (overlay.b - base.b) * ratio,
            base.a + (overlay.a - base.a) * ratio)
    }

    function desktopName(index) {
        const names = virtualDesktopInfo.desktopNames
        if (names && names.length > index && String(names[index]).length > 0) {
            return String(names[index])
        }
        return "Desktop " + (index + 1)
    }

    function isCurrentDesktop(desktopId) {
        return String(desktopId) === String(virtualDesktopInfo.currentDesktop)
    }

    Timer {
        id: pendingMoveResetTimer
        interval: 1200
        onTriggered: {
            root.pendingMoveTaskKey = ""
            root.pendingMoveTargetName = ""
        }
    }

    component PanelIconButton: MouseArea {
        id: button

        property string iconName
        property string toolTipText
        property bool checked: false

        signal triggered()

        width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
        height: width
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: enabled ? 1 : 0.35

        onClicked: button.triggered()

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: button.containsPress
                ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.16)
                : button.checked
                    ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, button.containsMouse ? 0.22 : 0.16)
                    : button.containsMouse
                        ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)
                        : "transparent"

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
            }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: width
            source: button.iconName
            active: button.containsMouse || button.checked
        }

        PC3.ToolTip {
            text: button.toolTipText
            visible: button.containsMouse && button.toolTipText.length > 0
        }
    }

    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: allTasksModel
        filterByVirtualDesktop: false
        filterByActivity: true
        filterNotMaximized: false
        filterByScreen: true
        filterHidden: false
        activity: activityInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupApplications
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
        sortMode: root.sortByName ? TaskManager.TasksModel.SortAlpha : TaskManager.TasksModel.SortLastActivated
    }

    Rectangle {
        id: panelShadow
        anchors.fill: panelBackground
        anchors.topMargin: 2
        radius: panelBackground.radius
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    Rectangle {
        id: panelBackground
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.pixelAligned: false
        border.color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.14)
    }

    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                Layout.fillWidth: true
                text: i18n("Running")
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Row {
                spacing: 1

                Repeater {
                    model: [
                        { label: i18n("Recent"), byName: false },
                        { label: i18n("Name"), byName: true }
                    ]

                    delegate: MouseArea {
                        id: sortButton

                        required property var modelData
                        readonly property bool checked: root.sortByName === modelData.byName

                        width: Math.max(Kirigami.Units.gridUnit * 3.5, label.implicitWidth + Kirigami.Units.smallSpacing * 3)
                        height: Kirigami.Units.gridUnit * 1.6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sortByName = modelData.byName

                        Rectangle {
                            anchors.fill: parent
                            radius: Kirigami.Units.cornerRadius
                            color: sortButton.checked
                                ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, sortButton.containsMouse ? 0.28 : 0.2)
                                : sortButton.containsMouse
                                    ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)
                                    : "transparent"
                        }

                        PC3.Label {
                            id: label
                            anchors.centerIn: parent
                            text: sortButton.modelData.label
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            color: sortButton.checked ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }

        RowLayout {
            id: desktopStrip

            Layout.fillWidth: true
            visible: virtualDesktopInfo.numberOfDesktops > 1
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: i18n("Desktops")
                opacity: 0.7
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
            }

            Item {
                id: desktopDropSurface

                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 2.4

                function desktopIndexAt(x) {
                    if (virtualDesktopInfo.numberOfDesktops <= 0) {
                        return -1
                    }

                    const localX = desktopRow.mapFromItem(desktopDropSurface, x, 0).x
                    var nearestIndex = -1
                    var nearestDistance = Number.MAX_VALUE
                    for (var i = 0; i < virtualDesktopInfo.numberOfDesktops; ++i) {
                        const item = desktopRepeater.itemAt(i)
                        if (!item) {
                            continue
                        }

                        if (localX >= item.x && localX <= item.x + item.width) {
                            return i
                        }

                        const center = item.x + item.width / 2
                        const distance = Math.abs(localX - center)
                        if (distance < nearestDistance) {
                            nearestIndex = i
                            nearestDistance = distance
                        }
                    }
                    return nearestIndex
                }

                Row {
                    id: desktopRow

                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        id: desktopRepeater

                        model: virtualDesktopInfo.desktopIds

                        delegate: MouseArea {
                            id: desktopButton

                            required property int index
                            required property var modelData

                            readonly property bool checked: root.isCurrentDesktop(modelData)
                            readonly property string desktopLabel: root.desktopName(index)
                            readonly property bool dragHovered: desktopDropArea.containsDrag && root.dragTargetDesktopIndex === index

                            width: Math.max(Kirigami.Units.gridUnit * 5.5, (desktopRow.width / Math.max(1, virtualDesktopInfo.numberOfDesktops)) - Kirigami.Units.smallSpacing)
                            height: desktopRow.height
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.folio.activateVirtualDesktop(modelData)

                            Rectangle {
                                anchors.fill: parent
                                radius: Kirigami.Units.cornerRadius
                                scale: desktopButton.dragHovered ? 1.03 : 1
                                color: desktopButton.checked
                                    ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, desktopButton.containsMouse || desktopButton.dragHovered ? 0.32 : 0.24)
                                    : desktopButton.dragHovered
                                        ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.18)
                                        : desktopButton.containsMouse
                                        ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)
                                        : root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.045)
                                border.width: 1
                                border.pixelAligned: false
                                border.color: desktopButton.checked || desktopButton.dragHovered
                                    ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.55)
                                    : root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.14)

                                Behavior on color {
                                    ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                                }
                                Behavior on scale {
                                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: Kirigami.Units.smallSpacing / 2
                                height: Math.max(2, Math.round(Kirigami.Units.devicePixelRatio))
                                radius: height / 2
                                visible: desktopButton.checked
                                color: Kirigami.Theme.highlightColor
                            }

                            PC3.Label {
                                anchors.centerIn: parent
                                width: parent.width - Kirigami.Units.smallSpacing * 2
                                text: desktopButton.desktopLabel
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                font.weight: desktopButton.checked || desktopButton.dragHovered ? Font.Medium : Font.Normal
                                font.pixelSize: Math.min(Kirigami.Theme.defaultFont.pixelSize, parent.height * 0.42)
                                color: desktopButton.checked || desktopButton.dragHovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                            }
                        }
                    }
                }

                DropArea {
                    id: desktopDropArea

                    anchors.fill: parent
                    keys: ["folio-running-task"]

                    onEntered: (drag) => {
                        root.dragTargetDesktopIndex = desktopDropSurface.desktopIndexAt(drag.x)
                        drag.accept(Qt.MoveAction)
                    }
                    onPositionChanged: (drag) => {
                        root.dragTargetDesktopIndex = desktopDropSurface.desktopIndexAt(drag.x)
                        drag.accept(Qt.MoveAction)
                    }
                    onExited: root.dragTargetDesktopIndex = -1
                    onDropped: (drop) => {
                        const desktopIndex = desktopDropSurface.desktopIndexAt(drop.x)
                        const desktopId = desktopIndex >= 0 ? virtualDesktopInfo.desktopIds[desktopIndex] : ""
                        if (!drop.source || !drop.source.moveToDesktop || String(desktopId).length === 0) {
                            root.dragTargetDesktopIndex = -1
                            return
                        }

                        drop.source.moveToDesktop(desktopId, desktopIndex)
                        root.dragTargetDesktopIndex = -1
                        drop.accept(Qt.MoveAction)
                    }
                }
            }
        }

        GridView {
            id: taskGrid

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: tasksModel
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            readonly property int columns: Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 14)))
            cellWidth: Math.floor(width / columns)
            cellHeight: Kirigami.Units.gridUnit * 10

            delegate: Item {
                id: taskCard

                required property int index
                required property var model

                width: taskGrid.cellWidth - Kirigami.Units.smallSpacing
                height: taskGrid.cellHeight - Kirigami.Units.smallSpacing

                readonly property var modelIndex: tasksModel.makeModelIndex(index)
                readonly property var winIds: model.WinIdList ? model.WinIdList : []
                readonly property int previewCount: Math.max(1, Math.min(2, winIds.length))
                readonly property bool activeTask: model.IsActive === true
                readonly property bool minimizedTask: model.IsMinimized === true
                readonly property bool maximizedTask: model.IsMaximized === true
                readonly property bool groupTask: model.IsGroupParent === true
                readonly property bool desktopsChangeable: model.IsVirtualDesktopsChangeable === true
                readonly property string storageId: root.taskStorageId(model)
                readonly property string taskKey: root.taskKey(model)
                readonly property bool pinned: storageId !== "" && root.folio.FavouritesModel.containsApplication(storageId)
                readonly property bool pendingMove: root.pendingMoveTaskKey === taskKey

                function taskIndexForPreview(previewIndex) {
                    return taskCard.groupTask
                        ? tasksModel.makeModelIndex(taskCard.index, previewIndex)
                        : taskCard.modelIndex
                }

                function titleForPreview(previewIndex) {
                    if (!taskCard.groupTask) {
                        return taskCard.model.display || ""
                    }
                    return tasksModel.data(tasksModel.makeModelIndex(taskCard.index, previewIndex), 0) || taskCard.model.display || ""
                }

                function activate(previewIndex) {
                    tasksModel.requestActivate(taskIndexForPreview(previewIndex || 0))
                    root.taskActivated()
                }

                function moveToDesktop(desktopId, desktopIndex) {
                    if (!taskCard.desktopsChangeable || String(desktopId).length === 0) {
                        return
                    }

                    root.markTaskMove(taskCard.taskKey, desktopIndex)
                    tasksModel.requestVirtualDesktops(taskCard.modelIndex, [desktopId])
                }

                Item {
                    id: dragProxy

                    parent: root
                    width: taskCard.width
                    height: taskCard.height
                    z: 1000
                    visible: cardArea.drag.active
                    opacity: 0.9

                    Drag.active: cardArea.drag.active
                    Drag.hotSpot.x: cardArea.pressX
                    Drag.hotSpot.y: cardArea.pressY
                    Drag.keys: ["folio-running-task"]
                    Drag.proposedAction: Qt.MoveAction
                    Drag.source: taskCard
                    Drag.supportedActions: Qt.MoveAction

                    Rectangle {
                        anchors.fill: parent
                        radius: Kirigami.Units.cornerRadius
                        color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.2)
                        border.width: 1
                        border.pixelAligned: false
                        border.color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.6)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Layout.preferredWidth
                            source: taskCard.model.decoration
                        }

                        PC3.Label {
                            Layout.fillWidth: true
                            text: taskCard.model.display || ""
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                MouseArea {
                    id: cardArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: taskCard.desktopsChangeable ? Qt.OpenHandCursor : Qt.PointingHandCursor
                    enabled: !taskCard.pendingMove
                    property real pressX: width / 2
                    property real pressY: height / 2
                    property bool wasDragged: false
                    drag.target: taskCard.desktopsChangeable ? dragProxy : undefined
                    drag.threshold: Math.max(4, Kirigami.Units.smallSpacing)
                    drag.smoothed: false

                    onPressed: (mouse) => {
                        wasDragged = false
                        pressX = mouse.x
                        pressY = mouse.y
                        const pos = taskCard.mapToItem(root, 0, 0)
                        dragProxy.x = pos.x
                        dragProxy.y = pos.y
                    }

                    onPositionChanged: {
                        if (drag.active) {
                            wasDragged = true
                        }
                    }

                    onReleased: {
                        if (wasDragged) {
                            dragProxy.Drag.drop()
                        }
                    }

                    onClicked: {
                        if (!wasDragged) {
                            taskCard.activate(0)
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: taskCard.activeTask
                        ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, cardArea.containsMouse ? 0.18 : 0.12)
                        : cardArea.containsMouse
                            ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)
                            : root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.04)
                    border.width: 1
                    border.pixelAligned: false
                    border.color: taskCard.activeTask
                        ? root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.5)
                        : root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)

                    Behavior on color {
                        ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Row {
                        id: previewRow
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: taskCard.previewCount

                            delegate: MouseArea {
                                id: previewArea

                                required property int index
                                readonly property string childUuid: taskCard.winIds.length > index ? taskCard.winIds[index] : ""

                                width: (previewRow.width - previewRow.spacing * (taskCard.previewCount - 1)) / taskCard.previewCount
                                height: previewRow.height
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: taskCard.activate(index)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Kirigami.Units.cornerRadius
                                    color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, previewArea.containsMouse ? 0.1 : 0.06)
                                    border.width: 1
                                    border.pixelAligned: false
                                    border.color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.14)
                                }

                                Loader {
                                    id: thumbnailLoader
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    active: previewArea.childUuid !== "" && root.visible
                                    sourceComponent: PipeWireThumbnail {
                                        windowUuid: previewArea.childUuid
                                    }
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.large
                                    height: width
                                    source: taskCard.model.decoration
                                    visible: !thumbnailLoader.item || !thumbnailLoader.item.hasThumbnail
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: titleLabel.implicitHeight + Kirigami.Units.smallSpacing
                                    radius: Kirigami.Units.cornerRadius
                                    color: Qt.rgba(0, 0, 0, 0.48)
                                    visible: taskCard.previewCount > 1

                                    PC3.Label {
                                        id: titleLabel
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: Kirigami.Units.smallSpacing
                                        text: taskCard.titleForPreview(previewArea.index)
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Layout.preferredWidth
                            source: taskCard.model.decoration
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            PC3.Label {
                                Layout.fillWidth: true
                                text: taskCard.model.display || ""
                                font.weight: taskCard.activeTask ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Row {
                                spacing: Kirigami.Units.smallSpacing

                                PC3.Label {
                                    text: taskCard.activeTask ? i18n("Active") : taskCard.minimizedTask ? i18n("Minimized") : i18n("Open")
                                    opacity: 0.65
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                                }

                                PC3.Label {
                                    visible: taskCard.maximizedTask
                                    text: i18n("Maximized")
                                    opacity: 0.65
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                                }

                                PC3.Label {
                                    visible: taskCard.winIds.length > 1
                                    text: i18np("%1 window", "%1 windows", taskCard.winIds.length)
                                    opacity: 0.65
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Item { Layout.fillWidth: true }

                        PanelIconButton {
                            iconName: taskCard.pinned ? "emblem-favorite" : "window-pin"
                            toolTipText: taskCard.pinned ? i18n("Pinned") : i18n("Pin to Dock")
                            checked: taskCard.pinned
                            enabled: taskCard.storageId !== "" && !taskCard.pinned && !root.folio.FolioSettings.lockLayout
                            onTriggered: root.folio.FavouritesModel.addApplication(taskCard.storageId)
                        }

                        PanelIconButton {
                            iconName: taskCard.minimizedTask ? "window-restore" : "window-minimize"
                            toolTipText: taskCard.minimizedTask ? i18n("Restore") : i18n("Minimize")
                            onTriggered: tasksModel.requestToggleMinimized(taskCard.modelIndex)
                        }

                        PanelIconButton {
                            iconName: taskCard.maximizedTask ? "window-restore" : "window-maximize"
                            toolTipText: taskCard.maximizedTask ? i18n("Restore") : i18n("Maximize")
                            enabled: !taskCard.groupTask
                            onTriggered: tasksModel.requestToggleMaximized(taskCard.modelIndex)
                        }

                        PanelIconButton {
                            iconName: "window-close"
                            toolTipText: taskCard.winIds.length > 1 ? i18n("Close All") : i18n("Close")
                            onTriggered: tasksModel.requestClose(taskCard.modelIndex)
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    visible: taskCard.pendingMove
                    color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.18)
                    border.width: 1
                    border.pixelAligned: false
                    border.color: root.mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.55)

                    PC3.Label {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.gridUnit
                        text: i18n("Moving to %1", root.pendingMoveTargetName)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.weight: Font.Medium
                        color: Kirigami.Theme.highlightColor
                    }
                }
            }

            PC3.ScrollBar.vertical: PC3.ScrollBar {
                interactive: true
                enabled: taskGrid.contentHeight > taskGrid.height
                implicitWidth: Kirigami.Units.smallSpacing
            }

            PC3.Label {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: taskGrid.count === 0
                text: i18n("No windows on this desktop")
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.65
                wrapMode: Text.WordWrap
            }
        }
    }
}
