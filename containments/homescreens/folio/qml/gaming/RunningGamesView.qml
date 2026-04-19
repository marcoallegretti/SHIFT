// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3
import org.kde.taskmanager as TaskManager

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

Item {
    id: root

    implicitHeight: taskList.count > 0 ? column.implicitHeight : 0
    readonly property bool hasTasks: taskList.count > 0

    signal taskActivated()
    signal moveDownRequested()

    function focusFirstTask() {
        if (!hasTasks) {
            return;
        }
        taskList.currentIndex = Math.max(0, taskList.currentIndex)
        taskList.positionViewAtIndex(taskList.currentIndex, ListView.Visible)
        taskList.forceActiveFocus()
    }

    TaskManager.VirtualDesktopInfo { id: vdInfo }
    TaskManager.ActivityInfo    { id: actInfo }

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMaximized: false
        filterByScreen: true
        filterHidden: false
        virtualDesktop: vdInfo.currentDesktop
        activity: actInfo.currentActivity
        groupMode: TaskManager.TasksModel.GroupApplications
    }

    Behavior on implicitHeight {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing
        visible: taskList.count > 0

        Kirigami.Heading {
            level: 2
            text: i18n("Running")
        }

        ListView {
            id: taskList
            Layout.fillWidth: true
            implicitHeight: contentHeight
            model: tasks
            orientation: ListView.Horizontal
            spacing: Kirigami.Units.largeSpacing
            clip: true
            keyNavigationEnabled: true
            currentIndex: 0

            onActiveFocusChanged: {
                if (activeFocus && count > 0 && currentIndex < 0) {
                    currentIndex = 0
                }
            }

            Keys.onLeftPressed: {
                if (count <= 0) {
                    return
                }
                currentIndex = Math.max(0, currentIndex - 1)
                positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Keys.onRightPressed: {
                if (count <= 0) {
                    return
                }
                currentIndex = Math.min(count - 1, currentIndex + 1)
                positionViewAtIndex(currentIndex, ListView.Contain)
            }

            Keys.onDownPressed: root.moveDownRequested()
            Keys.onReturnPressed: currentItem && currentItem.activate()
            Keys.onEnterPressed: currentItem && currentItem.activate()

            delegate: QQC2.ItemDelegate {
                id: taskItem

                required property var decoration
                required property var winIdList

                width: Kirigami.Units.gridUnit * 8
                height: Kirigami.Units.gridUnit * 5

                readonly property var modelIndex: tasks.makeModelIndex(index)
                readonly property bool isCurrent: ListView.isCurrentItem && taskList.activeFocus
                readonly property string titleText: typeof model !== "undefined" && model.display ? model.display : ""

                function activate() {
                    tasks.requestActivate(taskItem.modelIndex)
                    root.taskActivated()
                }

                onClicked: {
                    taskList.currentIndex = index
                    activate()
                }

                Keys.onReturnPressed: activate()
                Keys.onEnterPressed: activate()

                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    color: taskItem.isCurrent
                           ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                     Kirigami.Theme.highlightColor.b, 0.25)
                           : resumeArea.containsPress
                           ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                     Kirigami.Theme.highlightColor.b, 0.3)
                           : resumeArea.containsMouse
                           ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                     Kirigami.Theme.textColor.b, 0.1)
                           : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                     Kirigami.Theme.textColor.b, 0.06)

                    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Kirigami.Units.iconSizes.large
                        implicitHeight: Kirigami.Units.iconSizes.large
                        source: taskItem.decoration
                    }

                    PC3.Label {
                        Layout.fillWidth: true
                        text: taskItem.titleText
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                    }
                }

                // Close button (top-right corner)
                QQC2.ToolButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Kirigami.Units.smallSpacing / 2
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    icon.name: "window-close-symbolic"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: tasks.requestClose(taskItem.modelIndex)
                }

                MouseArea {
                    id: resumeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    // Leave room for the close button
                    onClicked: {
                        taskList.currentIndex = index
                        taskItem.activate()
                    }
                }
            }
        }
    }
}
