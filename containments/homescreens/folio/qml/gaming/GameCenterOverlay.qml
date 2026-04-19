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
            root.folio.ApplicationListSearchModel.categoryFilter = "Game"
            if (runningGames.hasTasks) {
                runningGames.focusFirstTask()
            } else {
                grid.forceActiveFocus()
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

                // Filter the app list to the Games XDG category.
                // ApplicationListSearchModel.categoryFilter is declared in
                // applicationlistmodel.h and filters on the CategoriesRole of
                // ApplicationListModel.
                model: root.folio.ApplicationListSearchModel

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

                Keys.onReturnPressed: currentItem && currentItem.launch()
                Keys.onEnterPressed: currentItem && currentItem.launch()
                Keys.onEscapePressed: root.dismissRequested()

                delegate: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight

                    GameTile {
                        anchors.fill: parent
                        folio: root.folio
                        application: model.delegate ? model.delegate.application : null
                        isCurrent: GridView.isCurrentItem && grid.activeFocus
                        onLaunchRequested: root.gameStarted()
                    }
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
                    onTriggered: ShellSettings.Settings.gamingModeEnabled = false
                }
            ]
            onClosed: exitGamingDialog.active = false
        }
    }
}
