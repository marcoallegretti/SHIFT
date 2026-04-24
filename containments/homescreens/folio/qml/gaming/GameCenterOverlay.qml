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
import org.kde.plasma.private.mobileshell.screenbrightnessplugin as ScreenBrightness
import org.kde.layershell 1.0 as LayerShell
import org.kde.plasma.clock

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

Window {
    id: root

    required property var folio
    property int launchTaskBaseline: 0

    signal gameStarted()
    signal dismissRequested()

    readonly property string actionButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonA)
    readonly property string backButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonB)
    readonly property string closeButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonX)
    readonly property string exitButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonY)
    readonly property string leftShoulderLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonLeftShoulder)
    readonly property string rightShoulderLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonRightShoulder)
    readonly property string quickSettingsButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonBack)
    readonly property string searchButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonStart)

    function pulsePrimaryGamepad(lowIntensity, highIntensity, durationMs) {
        var pad = GamingShell.GamepadManager.primaryGamepad
        if (!pad || !pad.hasRumble) {
            return
        }
        pad.rumble(lowIntensity, highIntensity, durationMs)
    }

    function requestExitGamingMode() {
        pulsePrimaryGamepad(9000, 15000, 60)
        exitGamingDialog.active = true
        exitGamingDialog.item.open()
    }

    function launchGame(index) {
        pulsePrimaryGamepad(14000, 22000, 80)
        launchTaskBaseline = runningGames.taskCount
        GamingShell.GameLauncherProvider.launch(index)
    }

    function launchGameByStorageId(storageId) {
        pulsePrimaryGamepad(14000, 22000, 80)
        launchTaskBaseline = runningGames.taskCount
        GamingShell.GameLauncherProvider.launchByStorageId(storageId)
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

    Connections {
        target: GamingShell.GameLauncherProvider

        function onGameLaunched(name) {
            launchFade.restart()
        }

        function onGameLaunchFailed(name, error) {
            launchErrorTimer.restart()
        }
    }

    Timer {
        id: launchErrorTimer
        interval: 6000
        repeat: false
        onTriggered: GamingShell.GameLauncherProvider.clearLastLaunchError()
    }

    onVisibleChanged: {
        if (visible) {
            GamingShell.GameLauncherProvider.filterString = ""
            GamingShell.GameLauncherProvider.sourceFilter = ""
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
            // Route to quick settings panel when open
            if (quickSettings.opened) {
                switch (button) {
                case GamingShell.GamepadManager.ButtonDPadUp:
                    quickSettings.gamepadUp()
                    return
                case GamingShell.GamepadManager.ButtonDPadDown:
                    quickSettings.gamepadDown()
                    return
                case GamingShell.GamepadManager.ButtonDPadLeft:
                    quickSettings.gamepadLeft()
                    return
                case GamingShell.GamepadManager.ButtonDPadRight:
                    quickSettings.gamepadRight()
                    return
                case GamingShell.GamepadManager.ButtonA:
                    quickSettings.gamepadAccept()
                    return
                case GamingShell.GamepadManager.ButtonB:
                case GamingShell.GamepadManager.ButtonBack:
                    quickSettings.close()
                    return
                }
                return // eat all other buttons while panel is open
            }

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
                if (runningGames.activeFocus) {
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
                if (runningGames.activeFocus) {
                    runningGames.activateCurrent()
                } else if (grid.activeFocus && grid.currentItem) {
                    root.launchGame(grid.currentIndex)
                }
                break
            case GamingShell.GamepadManager.ButtonX:
                if (runningGames.activeFocus) {
                    runningGames.closeCurrent()
                }
                break
            case GamingShell.GamepadManager.ButtonB:
                root.dismissRequested()
                break
            case GamingShell.GamepadManager.ButtonY:
                root.requestExitGamingMode()
                break
            case GamingShell.GamepadManager.ButtonLeftShoulder:
                root.cycleSourceFilter(-1)
                break
            case GamingShell.GamepadManager.ButtonRightShoulder:
                root.cycleSourceFilter(1)
                break
            case GamingShell.GamepadManager.ButtonStart:
                if (searchField.activeFocus) {
                    grid.forceActiveFocus()
                } else {
                    searchField.forceActiveFocus()
                }
                break
            case GamingShell.GamepadManager.ButtonBack:
                quickSettings.toggle()
                pulsePrimaryGamepad(7000, 11000, 40)
                break
            }
        }

        function onAxisChanged(axis, value, gamepadIndex) {
            if (axis === GamingShell.GamepadManager.AxisLeftX) {
                stickState.leftX = value
            } else if (axis === GamingShell.GamepadManager.AxisLeftY) {
                stickState.leftY = value
            } else if (axis === GamingShell.GamepadManager.AxisRightY) {
                stickState.rightY = value
            }
        }
    }

    // Left-stick navigation state + repeat timer
    QtObject {
        id: stickState
        property real leftX: 0
        property real leftY: 0
        property real rightY: 0
        readonly property real deadzone: 0.4
    }

    function navigateByStick() {
        // Route stick to quick settings when open
        if (quickSettings.opened) {
            if (stickState.leftY < -stickState.deadzone) {
                quickSettings.gamepadUp()
            } else if (stickState.leftY > stickState.deadzone) {
                quickSettings.gamepadDown()
            }
            if (stickState.leftX < -stickState.deadzone) {
                quickSettings.gamepadLeft()
            } else if (stickState.leftX > stickState.deadzone) {
                quickSettings.gamepadRight()
            }
            return
        }

        if (stickState.leftY < -stickState.deadzone) {
            if (grid.activeFocus) {
                if (grid.currentIndex < grid.columns && runningGames.hasTasks) {
                    runningGames.focusFirstTask()
                } else {
                    grid.moveCurrentIndexUp()
                }
            }
        } else if (stickState.leftY > stickState.deadzone) {
            if (runningGames.activeFocus) {
                grid.forceActiveFocus()
            } else if (grid.activeFocus) {
                grid.moveCurrentIndexDown()
            }
        }
        if (stickState.leftX < -stickState.deadzone && grid.activeFocus) {
            grid.moveCurrentIndexLeft()
        } else if (stickState.leftX > stickState.deadzone && grid.activeFocus) {
            grid.moveCurrentIndexRight()
        }
    }

    Timer {
        id: stickNavTimer
        interval: 150
        repeat: true
        running: root.visible
                 && (Math.abs(stickState.leftX) > stickState.deadzone
                     || Math.abs(stickState.leftY) > stickState.deadzone)
        onRunningChanged: if (running) root.navigateByStick()
        onTriggered: root.navigateByStick()
    }

    // Right stick: smooth scroll the grid view
    Timer {
        id: stickScrollTimer
        interval: 16  // ~60 Hz for smooth scrolling
        repeat: true
        running: root.visible && Math.abs(stickState.rightY) > stickState.deadzone
        onTriggered: {
            // Scale scroll speed with deflection, max ~12px per frame
            grid.contentY = Math.max(grid.originY,
                Math.min(grid.contentY + stickState.rightY * 12,
                         grid.contentHeight - grid.height))
        }
    }

    // Cycle through source filter tabs.
    readonly property var _sourceFilters: ["", "steam", "desktop", "waydroid", "lutris", "heroic"]
    function cycleSourceFilter(direction) {
        var current = _sourceFilters.indexOf(
            GamingShell.GameLauncherProvider.sourceFilter)
        if (current < 0) current = 0
        var next = (current + direction + _sourceFilters.length)
                   % _sourceFilters.length
        GamingShell.GameLauncherProvider.sourceFilter = _sourceFilters[next]
        sourceFilterBar.currentIndex = next
    }

    function sourceLabel(source) {
        switch (source) {
        case "steam":
            return i18n("Steam")
        case "waydroid":
            return i18n("Waydroid")
        case "lutris":
            return i18n("Lutris")
        case "heroic":
            return i18n("Heroic")
        case "flatpak":
            return i18n("Flatpak")
        default:
            return ""
        }
    }

    function sourceChipColor(source) {
        switch (source) {
        case "steam":
            return Qt.rgba(0.12, 0.23, 0.38, 0.9)
        case "waydroid":
            return Qt.rgba(0.13, 0.42, 0.36, 0.92)
        case "lutris":
            return Qt.rgba(0.42, 0.25, 0.11, 0.9)
        case "heroic":
            return Qt.rgba(0.37, 0.19, 0.16, 0.9)
        case "flatpak":
            return Qt.rgba(0.16, 0.26, 0.46, 0.9)
        default:
            return Qt.rgba(0.2, 0.2, 0.2, 0.72)
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
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    text: i18n("Game Center")
                    level: 1
                }

                Item { Layout.fillWidth: true }

                // ---- system status indicators ----
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.alignment: Qt.AlignVCenter

                    Clock { id: wallClock }

                    PC3.Label {
                        text: Qt.formatTime(wallClock.dateTime,
                              MobileShell.ShellUtil.isSystem24HourFormat ? "h:mm" : "h:mm ap")
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                        opacity: 0.8
                    }

                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        source: MobileShell.AudioInfo.icon
                        visible: MobileShell.AudioInfo.isVisible
                        opacity: 0.7
                    }

                    MobileShell.InternetIndicator {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.7
                    }

                    MobileShell.BluetoothIndicator {
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        opacity: 0.7
                    }

                    MobileShell.BatteryIndicator {
                        textPixelSize: Kirigami.Units.gridUnit * 0.55
                        opacity: 0.7
                    }
                }

                // ---- quick settings button ----
                QQC2.ToolButton {
                    icon.name: "configure"
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18n("Quick Settings")
                    onClicked: quickSettings.open()
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
                onTaskActivated: {
                    GamingShell.GameLauncherProvider.clearPendingLaunch()
                    root.gameStarted()
                }
                onMoveDownRequested: grid.forceActiveFocus()
                onTaskCountChanged: {
                    if (GamingShell.GameLauncherProvider.launchPending
                            && taskCount > root.launchTaskBaseline) {
                        GamingShell.GameLauncherProvider.clearPendingLaunch()
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: GamingShell.GameLauncherProvider.lastLaunchError
                visible: text.length > 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: GamingShell.GameLauncherProvider.launchPending

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    source: "system-run"
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: i18n("Launching %1…", GamingShell.GameLauncherProvider.pendingLaunchName)
                    opacity: 0.75
                }
            }

            // ---- continue playing ----
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: recentList.count > 0

                Kirigami.Heading {
                    level: 2
                    text: i18n("Continue Playing")
                }

                ListView {
                    id: recentList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                    orientation: ListView.Horizontal
                    spacing: Kirigami.Units.largeSpacing
                    clip: true

                    model: root.visible ? GamingShell.GameLauncherProvider.recentGames(5) : []

                    delegate: QQC2.ItemDelegate {
                        width: Kirigami.Units.gridUnit * 7
                        height: recentList.height

                        required property var modelData

                        readonly property bool hasArt: modelData.artwork && modelData.artwork.length > 0

                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius
                            color: parent.hovered ? Kirigami.Theme.hoverColor : "transparent"
                        }

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Image {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                source: hasArt ? "file://" + modelData.artwork : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: hasArt
                                asynchronous: true
                            }

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Kirigami.Units.iconSizes.large
                                implicitHeight: Kirigami.Units.iconSizes.large
                                source: modelData.icon
                                visible: !hasArt
                            }

                            PC3.Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            }
                        }

                        onClicked: root.launchGameByStorageId(modelData.storageId)
                    }
                }
            }

            // ---- search + filter ----
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Kirigami.SearchField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18n("Search games…")
                    onTextChanged: GamingShell.GameLauncherProvider.filterString = text

                    Keys.onEscapePressed: {
                        if (text.length > 0) {
                            clear()
                        } else {
                            root.dismissRequested()
                        }
                    }
                    Keys.onDownPressed: grid.forceActiveFocus()
                }

                QQC2.TabBar {
                    id: sourceFilterBar
                    Layout.alignment: Qt.AlignVCenter

                    QQC2.TabButton {
                        text: i18n("All")
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = ""
                    }
                    QQC2.TabButton {
                        text: "Steam"
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = "steam"
                    }
                    QQC2.TabButton {
                        text: i18n("Desktop")
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = "desktop"
                    }
                    QQC2.TabButton {
                        text: i18n("Waydroid")
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = "waydroid"
                    }
                    QQC2.TabButton {
                        text: "Lutris"
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = "lutris"
                    }
                    QQC2.TabButton {
                        text: "Heroic"
                        width: implicitWidth
                        onClicked: GamingShell.GameLauncherProvider.sourceFilter = "heroic"
                    }
                }
            }

            // ---- game grid ----

            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true

                model: GamingShell.GameLauncherProvider

                readonly property real minCellSize: Kirigami.Units.gridUnit * 8
                readonly property int columns: Math.max(2, Math.floor(width / minCellSize))

                cellWidth: Math.floor(width / columns)
                cellHeight: Math.floor(cellWidth * 1.5) + Kirigami.Units.gridUnit * 2

                keyNavigationEnabled: true
                highlightMoveDuration: 0
                highlight: null

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: grid.count === 0 && !GamingShell.GameLauncherProvider.loading
                    icon.name: "games-none"
                    text: searchField.text.length > 0
                          ? i18n("No games match your search")
                          : i18n("No games found")
                    explanation: searchField.text.length > 0
                                 ? ""
                                 : i18n("Install games, or enable supported Waydroid apps from the Waydroid applications page")
                }

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
                        root.launchGame(currentIndex)
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
                    required property string artwork

                    readonly property bool hasArt: artwork.length > 0

                    QQC2.ItemDelegate {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        padding: 0

                        readonly property bool isCurrent: GridView.isCurrentItem && grid.activeFocus

                        background: Rectangle {
                            Kirigami.Theme.colorSet: Kirigami.Theme.Button
                            color: parent.isCurrent
                                   ? Kirigami.Theme.highlightColor
                                   : (parent.hovered ? Kirigami.Theme.hoverColor : "transparent")
                            radius: Kirigami.Units.cornerRadius
                        }

                        contentItem: Item {
                            // ---- cover art tile ----
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0
                                visible: hasArt

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Kirigami.Units.cornerRadius
                                    clip: true
                                    color: "transparent"

                                    Image {
                                        anchors.fill: parent
                                        source: hasArt ? "file://" + artwork : ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: Kirigami.Units.smallSpacing
                                        visible: source !== "desktop"
                                        radius: height / 2
                                        color: root.sourceChipColor(source)
                                        implicitHeight: chipLabel.implicitHeight + Kirigami.Units.smallSpacing
                                        implicitWidth: chipLabel.implicitWidth + Kirigami.Units.largeSpacing

                                        PC3.Label {
                                            id: chipLabel
                                            anchors.centerIn: parent
                                            text: root.sourceLabel(source)
                                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.72
                                            font.weight: Font.DemiBold
                                            color: "white"
                                        }
                                    }
                                }

                                // Title beneath artwork
                                PC3.Label {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                                    text: name
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: Kirigami.Units.smallSpacing
                                    rightPadding: Kirigami.Units.smallSpacing
                                    color: parent.parent.parent.isCurrent
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Kirigami.Theme.textColor
                                }
                            }

                            // ---- fallback icon tile ----
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                visible: !hasArt
                                spacing: Kirigami.Units.smallSpacing

                                Item { Layout.fillHeight: true }

                                Kirigami.Icon {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: Kirigami.Units.iconSizes.huge
                                    implicitHeight: Kirigami.Units.iconSizes.huge
                                    source: icon

                                    scale: parent.parent.parent.isCurrent ? 1.08 : 1.0
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
                                    color: parent.parent.parent.isCurrent
                                           ? Kirigami.Theme.highlightedTextColor
                                           : Kirigami.Theme.textColor
                                }

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: source !== "desktop"
                                    radius: height / 2
                                    color: root.sourceChipColor(source)
                                    implicitHeight: sourceChipLabel.implicitHeight + Kirigami.Units.smallSpacing
                                    implicitWidth: sourceChipLabel.implicitWidth + Kirigami.Units.largeSpacing

                                    PC3.Label {
                                        id: sourceChipLabel
                                        anchors.centerIn: parent
                                        text: root.sourceLabel(source)
                                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.72
                                        font.weight: Font.DemiBold
                                        color: "white"
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        onClicked: root.launchGame(index)
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
                        required property var device

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
                        PC3.Label {
                            text: device.touchpadCount > 0 ? i18n("Touchpad") : ""
                            visible: device.touchpadCount > 0
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                            opacity: 0.6
                        }
                        PC3.Label {
                            text: device.hasGyro ? i18n("Gyro") : ""
                            visible: device.hasGyro
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                            opacity: 0.6
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Gamepad legend
                PC3.Label {
                    text: runningGames.hasTasks
                         ? i18n("%1: Select  %2: Close  %3: Back  %4: Exit  %5: Settings  %6: Search",
                             actionButtonLabel, closeButtonLabel, backButtonLabel, exitButtonLabel,
                             quickSettingsButtonLabel, searchButtonLabel)
                         : i18n("%1: Select  %2: Back  %3: Exit  %4/%5: Filter  %6: Settings  %7: Search",
                             actionButtonLabel, backButtonLabel, exitButtonLabel, leftShoulderLabel,
                             rightShoulderLabel, quickSettingsButtonLabel, searchButtonLabel)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.75
                    opacity: 0.5
                }
            }
        }
    }

    // Quick settings slide-out panel
    GamingQuickSettings {
        id: quickSettings
        z: 50
    }

    // Launch transition: brief fade to black, then dismiss
    Rectangle {
        id: launchCurtain
        anchors.fill: parent
        color: "black"
        opacity: 0
        z: 100

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InQuad }
        }
    }

    Timer {
        id: launchFade
        interval: 300
        onTriggered: {
            launchCurtain.opacity = 0
            root.gameStarted()
        }
        onRunningChanged: {
            if (running) {
                launchCurtain.opacity = 1
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
