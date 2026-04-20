// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell
import org.kde.layershell 1.0 as LayerShell

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

Window {
    id: root

    required property var folio

    signal gameStarted()
    signal dismissRequested()

    function requestExitGamingMode() {
        exitGamingDialog.active = true
        exitGamingDialog.item.open()
    }

    width: Screen.width
    height: Screen.height
    color: "transparent"
    flags: Qt.FramelessWindowHint

    LayerShell.Window.scope: "gaming-overlay"
    LayerShell.Window.layer: LayerShell.Window.LayerTop
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    // Animate opacity on show/hide
    opacity: visible ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    onVisibleChanged: {
        if (visible) {
            GamingShell.GameLauncherProvider.refresh()
            if (runningGames.hasTasks) {
                runningGames.focusFirstTask()
            } else {
                grid.forceActiveFocus()
            }
        }
    }

    // Translate gamepad buttons to focus navigation
    Connections {
        target: GamingShell.GamepadManager
        enabled: root.visible

        function onButtonPressed(button, gamepadIndex) {
            switch (button) {
            case GamingShell.GamepadManager.ButtonDPadUp:
                if (grid.activeFocus) {
                    if (grid.currentIndex < grid.columns && runningGames.hasTasks) {
                        runningGames.focusFirstTask()
                    } else {
                        grid.moveCurrentIndexUp()
                    }
                }
                break
            case GamingShell.GamepadManager.ButtonDPadDown:
                if (taskList.activeFocus || runningGames.activeFocus) {
                    grid.forceActiveFocus()
                } else if (grid.activeFocus) {
                    grid.moveCurrentIndexDown()
                }
                break
            case GamingShell.GamepadManager.ButtonDPadLeft:
                if (grid.activeFocus) grid.moveCurrentIndexLeft()
                break
            case GamingShell.GamepadManager.ButtonDPadRight:
                if (grid.activeFocus) grid.moveCurrentIndexRight()
                break
            case GamingShell.GamepadManager.ButtonA:
                if (grid.activeFocus && grid.currentItem) {
                    GamingShell.GameLauncherProvider.launch(grid.currentIndex)
                    root.gameStarted()
                } else if (taskList.activeFocus && taskList.currentItem) {
                    taskList.currentItem.activate()
                }
                break
            case GamingShell.GamepadManager.ButtonB:
                root.dismissRequested()
                break
            case GamingShell.GamepadManager.ButtonY:
                root.requestExitGamingMode()
                break
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                       Kirigami.Theme.backgroundColor.g,
                       Kirigami.Theme.backgroundColor.b, 0.92)
    }

    FocusScope {
        id: contentRoot
        anchors.fill: parent
        focus: root.visible

        // Escape only dismisses the overlay; exiting gaming mode is explicit.
        Keys.onEscapePressed: root.dismissRequested()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.largeSpacing

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true

                Kirigami.Heading {
                    Layout.fillWidth: true
                    text: i18n("Game Center")
                    level: 1
                }

                QQC2.ToolButton {
                    icon.name: "window-close"
                    text: i18n("Exit Gaming Mode")
                    display: QQC2.AbstractButton.TextBesideIcon
                    Keys.onReturnPressed: clicked()
                    Keys.onEnterPressed: clicked()
                    onClicked: root.requestExitGamingMode()
                }
            }

            // ---- running games ----
            RunningGamesView {
                id: runningGames
                Layout.fillWidth: true
                onTaskActivated: root.gameStarted()
                onMoveDownRequested: grid.forceActiveFocus()
            }

            // ---- game grid ----
            Kirigami.Heading {
                level: 2
                text: i18n("Library")
            }

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true

                model: GamingShell.GameLauncherProvider

                readonly property real minCellSize: Kirigami.Units.gridUnit * 7
                readonly property int columns: Math.max(2, Math.floor(width / minCellSize))

                cellWidth: Math.floor(width / columns)
                cellHeight: cellWidth + Kirigami.Units.gridUnit * 2

                keyNavigationEnabled: true
                highlightMoveDuration: 0
                highlight: null

                onActiveFocusChanged: {
                    if (activeFocus && count > 0 && currentIndex < 0) {
                        currentIndex = 0
                    }
                }

                Keys.onUpPressed: {
                    if (runningGames.hasTasks) {
                        runningGames.focusFirstTask()
                    }
                }

                Keys.onReturnPressed: {
                    if (currentIndex >= 0) {
                        GamingShell.GameLauncherProvider.launch(currentIndex)
                        root.gameStarted()
                    }
                }
                Keys.onEnterPressed: Keys.onReturnPressed(event)
                Keys.onEscapePressed: root.dismissRequested()

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    required property int index
                    required property string name
                    required property string icon
                    required property string source

                    QQC2.ItemDelegate {
                        anchors.fill: parent

                        readonly property bool isCurrent: GridView.isCurrentItem && grid.activeFocus

                        background: Rectangle {
                            Kirigami.Theme.colorSet: Kirigami.Theme.Button
                            color: parent.isCurrent
                                   ? Kirigami.Theme.highlightColor
                                   : (parent.hovered ? Kirigami.Theme.hoverColor : "transparent")
                            radius: Kirigami.Units.cornerRadius
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
                        }

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Kirigami.Units.iconSizes.huge
                                implicitHeight: Kirigami.Units.iconSizes.huge
                                source: icon

                                scale: parent.parent.isCurrent ? 1.08 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
                                }
                            }

                            PC3.Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.fillWidth: true
                                text: name
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                color: parent.parent.isCurrent
                                       ? Kirigami.Theme.highlightedTextColor
                                       : Kirigami.Theme.textColor
                            }

                            // Source badge
                            PC3.Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: source === "steam" ? "Steam"
                                    : source === "flatpak" ? "Flatpak"
                                    : ""
                                visible: source !== "desktop"
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                                opacity: 0.6
                            }
                        }

                        onClicked: {
                            GamingShell.GameLauncherProvider.launch(index)
                            root.gameStarted()
                        }
                    }
                }
            }

            // ---- controller status bar ----
            RowLayout {
                Layout.fillWidth: true
                visible: GamingShell.GamepadManager.hasGamepad
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    source: "input-gaming"
                }

                Repeater {
                    model: GamingShell.GamepadManager

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        required property string name
                        required property int battery
                        required property string type

                        PC3.Label {
                            text: name
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                        }
                        PC3.Label {
                            text: battery >= 0 ? battery + "%" : ""
                            visible: battery >= 0
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            opacity: 0.7
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Gamepad legend
                PC3.Label {
                    text: i18n("A: Select  B: Back  Y: Exit")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                    opacity: 0.5
                }
            }
        }
    }

    Loader {
        id: exitGamingDialog
        active: false
        anchors.fill: parent

        sourceComponent: Kirigami.PromptDialog {
            id: theExitDialog
            title: i18n("Leave gaming mode?")
            subtitle: i18n("Your games will keep running in the background.")
            standardButtons: Kirigami.Dialog.NoButton
            customFooterActions: [
                Kirigami.Action {
                    text: i18n("Keep Playing")
                    onTriggered: theExitDialog.close()
                },
                Kirigami.Action {
                    text: i18n("Leave")
                    onTriggered: {
                        ShellSettings.Settings.gamingModeEnabled = false
                        theExitDialog.close()
                    }
                }
            ]
            onClosed: exitGamingDialog.active = false
        }
    }
}
