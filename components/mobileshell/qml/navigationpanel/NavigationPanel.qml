/*
 *  SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
 *  SPDX-FileCopyrightText: 2021 Devin Lin <devin@kde.org>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.kquickcontrolsaddons 2.0
import org.kde.plasma.private.mobileshell.state as MobileShellState

Item {
    id: root

    property bool shadow: false
    property color backgroundColor
    property var foregroundColorGroup

    property NavigationPanelAction leftAction
    property NavigationPanelAction middleAction
    property NavigationPanelAction rightAction

    property NavigationPanelAction leftCornerAction
    property NavigationPanelAction rightCornerAction

    property real leftPadding: 0
    property real rightPadding: 0

    property bool isVertical: false

    // Convergence mode: show running-app task strip
    property bool convergenceMode: false
    property var taskModel: null
    property var virtualDesktopInfo: null

    // drop shadow for icons
    MultiEffect {
        anchors.fill: icons
        visible: shadow
        source: icons
        blurMax: 16
        shadowEnabled: true
        shadowVerticalOffset: 1
        shadowOpacity: 0.8
    }

    // background colour
    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Item {
        id: icons
        anchors.fill: parent

        property real buttonLength: 0

        NavigationPanelButton {
            id: leftCornerButton
            visible: root.leftCornerAction.visible
            Kirigami.Theme.colorSet: root.foregroundColorGroup
            Kirigami.Theme.inherit: false
            enabled: root.leftCornerAction.enabled
            shrinkSize: root.leftCornerAction.shrinkSize
            iconSource: root.leftCornerAction.iconSource
            onClicked: {
                if (enabled) {
                    root.leftCornerAction.triggered();
                }
            }
        }

        // button row (anchors provided by state)
        NavigationPanelButton {
            id: leftButton
            visible: root.leftAction.visible
            Kirigami.Theme.colorSet: root.foregroundColorGroup
            Kirigami.Theme.inherit: false
            enabled: root.leftAction.enabled
            shrinkSize: root.leftAction.shrinkSize
            iconSource: root.leftAction.iconSource
            onClicked: {
                if (enabled) {
                    root.leftAction.triggered();
                }
            }
        }

        NavigationPanelButton {
            id: middleButton
            anchors.centerIn: parent
            visible: root.middleAction.visible
            Kirigami.Theme.colorSet: root.foregroundColorGroup
            Kirigami.Theme.inherit: false
            enabled: root.middleAction.enabled
            shrinkSize: root.middleAction.shrinkSize
            iconSource: root.middleAction.iconSource
            onClicked: {
                if (enabled) {
                    root.middleAction.triggered();
                }
            }
        }

        NavigationPanelButton {
            id: rightButton
            visible: root.rightAction.visible
            Kirigami.Theme.colorSet: root.foregroundColorGroup
            Kirigami.Theme.inherit: false
            enabled: root.rightAction.enabled
            shrinkSize: root.rightAction.shrinkSize
            iconSource: root.rightAction.iconSource
            onClicked: {
                if (enabled) {
                    root.rightAction.triggered();
                }
            }
        }

        NavigationPanelButton {
            id: rightCornerButton
            visible: root.rightCornerAction.visible
            Kirigami.Theme.colorSet: root.foregroundColorGroup
            Kirigami.Theme.inherit: false
            enabled: root.rightCornerAction.enabled
            shrinkSize: root.rightCornerAction.shrinkSize
            iconSource: root.rightCornerAction.iconSource
            onClicked: {
                if (enabled) {
                    root.rightCornerAction.triggered();
                }
            }
        }

        // Running-app task strip for convergence (desktop) mode
        // NOTE: Disabled — running apps now shown in FavouritesBar dock
        ListView {
            id: taskStrip
            visible: false
            orientation: root.isVertical ? ListView.Vertical : ListView.Horizontal
            spacing: Kirigami.Units.smallSpacing
            clip: true
            interactive: root.isVertical ? contentHeight > height : contentWidth > width
            model: root.taskModel

            delegate: NavigationPanelButton {
                id: taskDelegate
                required property int index
                required property var model
                width: taskStrip.orientation === ListView.Horizontal ? height : taskStrip.width
                height: taskStrip.orientation === ListView.Horizontal ? taskStrip.height : taskStrip.width

                Kirigami.Theme.colorSet: root.foregroundColorGroup
                Kirigami.Theme.inherit: false
                iconSource: taskDelegate.model.decoration
                enabled: true
                shrinkSize: 0

                onClicked: {
                    if (!root.taskModel) return;
                    root.taskModel.requestActivate(root.taskModel.makeModelIndex(taskDelegate.index));
                }

                // Right-click context menu
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: taskContextMenu.popup()
                }

                Controls.Menu {
                    id: taskContextMenu
                    Controls.MenuItem {
                        text: taskDelegate.model.IsMinimized ? i18n("Restore") : i18n("Minimize")
                        icon.name: taskDelegate.model.IsMinimized ? "window-restore" : "window-minimize"
                        onTriggered: {
                            if (!root.taskModel) return;
                            root.taskModel.requestToggleMinimized(root.taskModel.makeModelIndex(taskDelegate.index))
                        }
                    }
                    Controls.MenuItem {
                        text: taskDelegate.model.IsMaximized ? i18n("Restore") : i18n("Maximize")
                        icon.name: taskDelegate.model.IsMaximized ? "window-restore" : "window-maximize"
                        onTriggered: {
                            if (!root.taskModel) return;
                            root.taskModel.requestToggleMaximized(root.taskModel.makeModelIndex(taskDelegate.index))
                        }
                    }
                    Controls.MenuSeparator {}
                    Controls.MenuItem {
                        text: i18n("Close")
                        icon.name: "window-close"
                        onTriggered: {
                            if (!root.taskModel) return;
                            root.taskModel.requestClose(root.taskModel.makeModelIndex(taskDelegate.index))
                        }
                    }
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
            }
        }

        // Virtual desktop switcher (convergence mode, multiple desktops)
        Row {
            id: workspaceIndicator
            visible: root.convergenceMode && root.virtualDesktopInfo !== null && root.virtualDesktopInfo.numberOfDesktops > 1
            spacing: Kirigami.Units.smallSpacing / 2

            Repeater {
                model: root.virtualDesktopInfo ? root.virtualDesktopInfo.desktopIds : []

                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: Kirigami.Units.gridUnit * 1.5
                    height: width
                    radius: Kirigami.Units.smallSpacing

                    color: modelData === root.virtualDesktopInfo.currentDesktop
                           ? Kirigami.Theme.highlightColor
                           : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        color: parent.modelData === root.virtualDesktopInfo.currentDesktop
                               ? Kirigami.Theme.highlightedTextColor
                               : Kirigami.Theme.textColor
                        font.pixelSize: parent.height * 0.6
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.virtualDesktopInfo.requestActivate(parent.modelData)
                    }
                }
            }
        }
    }

    states: [
        State {
            name: "vertical"
            when: root.isVertical
            PropertyChanges {
                target: icons
                anchors {
                    topMargin: root.leftPadding
                    bottomMargin: root.rightPadding
                }
                buttonLength: Math.min(Kirigami.Units.gridUnit * 10, icons.height * 0.7 / 3)
            }
            AnchorChanges {
                target: leftButton
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: middleButton.bottom
                }
            }
            PropertyChanges {
                target: leftButton
                width: parent.width
                height: icons.buttonLength
            }
            PropertyChanges {
                target: middleButton
                width: parent.width
                height: icons.buttonLength
            }
            AnchorChanges {
                target: rightButton
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: middleButton.top
                }
            }
            PropertyChanges {
                target: rightButton
                height: icons.buttonLength
                width: icons.width
            }
            AnchorChanges {
                target: rightCornerButton
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                }
            }
            PropertyChanges {
                target: rightCornerButton
                height: Kirigami.Units.gridUnit * 2
                width: icons.width
            }
            AnchorChanges {
                target: leftCornerButton
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                }
            }
            PropertyChanges {
                target: leftCornerButton
                height: Kirigami.Units.gridUnit * 2
                width: icons.width
            }
            // Task strip: vertical layout — positioned between leftCornerButton (bottom) and leftButton (above middle)
            AnchorChanges {
                target: taskStrip
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: leftButton.top
                    top: undefined
                }
            }
            PropertyChanges {
                target: taskStrip
                width: parent.width
                // Fill space between leftCorner (bottom) and the nav button group
                height: taskStrip.visible ? (leftButton.y - leftCornerButton.y - leftCornerButton.height - Kirigami.Units.smallSpacing * 2) : 0
            }
            // Workspace indicator: vertical — above rightCornerButton (top)
            AnchorChanges {
                target: workspaceIndicator
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: rightCornerButton.bottom
                }
            }
        }, State {
            name: "convergence-horizontal"
            when: !root.isVertical && root.convergenceMode
            PropertyChanges {
                target: icons
                anchors {
                    leftMargin: root.leftPadding
                    rightMargin: root.rightPadding
                }
                buttonLength: Math.min(Kirigami.Units.gridUnit * 8, icons.width * 0.7 / 3)
            }
            // Home button: far left
            AnchorChanges {
                target: middleButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                    right: undefined
                }
            }
            PropertyChanges {
                target: middleButton
                height: parent.height
                width: icons.buttonLength
                anchors.centerIn: undefined
            }
            // Overview button: far right
            AnchorChanges {
                target: leftButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: parent.right
                    left: undefined
                }
            }
            PropertyChanges {
                target: leftButton
                height: parent.height
                width: icons.buttonLength
            }
            // Hide close button (already not visible via action)
            PropertyChanges {
                target: rightButton
                height: parent.height
                width: 0
                visible: false
            }
            // Hide corner buttons in convergence
            PropertyChanges {
                target: leftCornerButton
                width: 0
                visible: false
            }
            PropertyChanges {
                target: rightCornerButton
                width: 0
                visible: false
            }
            // Workspace indicator: left of Overview button
            AnchorChanges {
                target: workspaceIndicator
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: leftButton.left
                    left: undefined
                }
            }
            // Task strip hidden
            PropertyChanges {
                target: taskStrip
                height: 0
                visible: false
            }
        }, State {
            name: "horizontal"
            when: !root.isVertical
            PropertyChanges {
                target: icons
                anchors {
                    leftMargin: root.leftPadding
                    rightMargin: root.rightPadding
                }
                buttonLength: Math.min(Kirigami.Units.gridUnit * 8, icons.width * 0.7 / 3)
            }
            AnchorChanges {
                target: leftButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: middleButton.left
                }
            }
            PropertyChanges {
                target: leftButton
                height: parent.height
                width: icons.buttonLength
            }
            PropertyChanges {
                target: middleButton
                height: parent.height
                width: icons.buttonLength
            }
            AnchorChanges {
                target: rightButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: middleButton.right
                }
            }
            PropertyChanges {
                target: rightButton
                height: parent.height
                width: icons.buttonLength
            }
            AnchorChanges {
                target: rightCornerButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    right: parent.right
                }
            }
            PropertyChanges {
                target: rightCornerButton
                height: parent.height
                width: Kirigami.Units.gridUnit * 2
            }
            AnchorChanges {
                target: leftCornerButton
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                }
            }
            PropertyChanges {
                target: leftCornerButton
                height: parent.height
                width: Kirigami.Units.gridUnit * 2
            }
            // Task strip: horizontal layout — positioned between leftCornerButton (left) and leftButton (near center)
            AnchorChanges {
                target: taskStrip
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: leftCornerButton.right
                    right: leftButton.left
                }
            }
            PropertyChanges {
                target: taskStrip
                height: parent.height
            }
            // Workspace indicator: horizontal — between rightButton and rightCornerButton
            AnchorChanges {
                target: workspaceIndicator
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: rightButton.right
                }
            }
        }
    ]
}
