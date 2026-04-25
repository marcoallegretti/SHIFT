// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell
import org.kde.layershell 1.0 as LayerShell

Window {
    id: root

    signal openRequested()

    // Guard against startup timing where Kirigami units may briefly be 0/NaN.
    // LayerShell surfaces must never be committed with zero size.
    readonly property real safeGridUnit: ((Kirigami.Units.gridUnit || 0) > 0) ? Kirigami.Units.gridUnit : 16

    property string toastMessage: ""
    property bool toastError: false
    readonly property bool toastActive: toastMessage.length > 0

    // Most-recently-played game for quick resume. Populated from recentGames(1)
    // and refreshed whenever the recent list changes.
    property var quickResumeGame: null
    readonly property bool hasQuickResume: quickResumeGame !== null

    // Window grows leftward from top-right anchor:
    //   toast active  → widest (needs room for message text)
    //   quick resume  → medium (game name + controls)
    //   idle          → compact (controls only)
    width: toastActive ? safeGridUnit * 16 : (hasQuickResume ? safeGridUnit * 14 : safeGridUnit * 4)
    height: toastActive ? safeGridUnit * 4 : safeGridUnit * 2
    color: "transparent"
    flags: Qt.FramelessWindowHint

    Behavior on width {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    Behavior on height {
        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }

    LayerShell.Window.scope: "gaming-hud"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: 0
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone

    // Driven by the Loader in folio/qml/main.qml — set false to fade out
    // before the Loader destroys the window.
    property bool showing: true

    opacity: showing ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
    }

    Timer {
        id: toastTimer
        onTriggered: root.toastMessage = ""
    }

    Connections {
        target: GamingShell.GameLauncherProvider
        function onGameLaunched(name) {
            root.toastMessage = i18n("Launching %1", name)
            root.toastError = false
            toastTimer.interval = 3000
            toastTimer.restart()
        }
        function onGameLaunchFailed(name, error) {
            root.toastMessage = error.length > 0 ? error : i18n("Failed to launch %1", name)
            root.toastError = true
            toastTimer.interval = 5000
            toastTimer.restart()
        }
        function onRecentGamesChanged() {
            const recent = GamingShell.GameLauncherProvider.recentGames(1)
            root.quickResumeGame = recent.length > 0 ? recent[0] : null
        }
    }

    Component.onCompleted: {
        const recent = GamingShell.GameLauncherProvider.recentGames(1)
        root.quickResumeGame = recent.length > 0 ? recent[0] : null
    }

    // ---- HUD pill (always visible, fills window width, grows leftward) ----
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        height: safeGridUnit * 2 - Kirigami.Units.smallSpacing * 2
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.55)

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Kirigami.Units.smallSpacing
                rightMargin: Kirigami.Units.smallSpacing
            }
            spacing: 0

            // Quick-resume section — only visible when a recent game exists
            QQC2.ToolButton {
                visible: root.hasQuickResume
                icon.name: "media-playback-start"
                icon.color: "white"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.quickResumeGame ? i18n("Resume %1", root.quickResumeGame.name) : ""
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    if (root.quickResumeGame) {
                        GamingShell.GameLauncherProvider.launchByStorageId(root.quickResumeGame.storageId)
                    }
                }
            }

            QQC2.Label {
                visible: root.hasQuickResume
                Layout.fillWidth: true
                text: root.quickResumeGame ? root.quickResumeGame.name : ""
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                elide: Text.ElideRight
                maximumLineCount: 1
                leftPadding: Kirigami.Units.smallSpacing
            }

            // Separator between quick-resume and controls
            Rectangle {
                visible: root.hasQuickResume
                width: 1
                implicitHeight: Kirigami.Units.gridUnit
                color: Qt.rgba(1, 1, 1, 0.25)
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Kirigami.Units.smallSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
            }

            // Game Center button
            QQC2.ToolButton {
                icon.name: "input-gaming"
                icon.color: "white"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Game Center")
                onClicked: root.openRequested()
            }

            // Primary gamepad battery
            QQC2.Label {
                visible: GamingShell.GamepadManager.hasGamepad
                         && GamingShell.GamepadManager.primaryGamepad
                         && GamingShell.GamepadManager.primaryGamepad.batteryPercent >= 0
                text: GamingShell.GamepadManager.primaryGamepad
                      ? GamingShell.GamepadManager.primaryGamepad.batteryPercent + "%"
                      : ""
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                rightPadding: Kirigami.Units.smallSpacing
            }
        }
    }

    // ---- toast pill (slides in below HUD pill when active) ----
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Kirigami.Units.smallSpacing
        height: safeGridUnit * 2 - Kirigami.Units.smallSpacing * 2
        radius: height / 2
        color: root.toastError ? Qt.rgba(0.75, 0.1, 0.05, 0.9) : Qt.rgba(0, 0, 0, 0.55)

        opacity: root.toastActive ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        RowLayout {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Kirigami.Units.largeSpacing
                rightMargin: Kirigami.Units.largeSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: root.toastError ? "dialog-warning" : "media-playback-start"
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: root.toastMessage
                color: "white"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
