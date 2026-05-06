// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import org.kde.kirigami as Kirigami

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents

import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell.windowplugin as WindowPlugin
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell

import org.kde.layershell 1.0 as LayerShell
import org.kde.plasma.private.sessions 2.0
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCM
import org.kde.kirigamiaddons.components as KirigamiAddonsComponents

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

import "./gaming"

import "./private"

ContainmentItem {
    id: root
    property var folio: root.plasmoid

    // Tracks whether the Game Center grid is visible within gaming mode.
    // If gaming mode is already enabled at startup, open it immediately so
    // the user is never left without controls.
    property bool gameCenterOpen: ShellSettings.Settings.gamingModeEnabled
    property bool showGameCenterHint: false

    // State saved when gaming mode activates, restored when it deactivates
    property string _savedPowerProfile: ""
    property bool _savedDnd: false
    property bool _gamingSessionActive: false

    function _applyGamingModeState(enabled) {
        root.gameCenterOpen = enabled
        GamingShell.GamepadManager.active = enabled

        if (enabled === root._gamingSessionActive) {
            return
        }

        if (enabled) {
            // Save current state and apply gaming optimizations
            root._savedDnd = MobileShellState.ShellDBusClient.doNotDisturb
            MobileShellState.ShellDBusClient.doNotDisturb = true

            if (GamingShell.PowerProfileControl.available) {
                root._savedPowerProfile = GamingShell.PowerProfileControl.activeProfile
                GamingShell.PowerProfileControl.activeProfile = "performance"
            }

            GamingShell.GameModeControl.requestStart()
            root._gamingSessionActive = true
        } else {
            // Restore previous state
            MobileShellState.ShellDBusClient.doNotDisturb = root._savedDnd

            if (GamingShell.PowerProfileControl.available && root._savedPowerProfile.length > 0) {
                GamingShell.PowerProfileControl.activeProfile = root._savedPowerProfile
            }

            GamingShell.GameModeControl.requestEnd()
            root._gamingSessionActive = false
        }
    }

    Timer {
        id: gameCenterHintTimer
        interval: 2600
        onTriggered: root.showGameCenterHint = false
    }

    Connections {
        target: ShellSettings.Settings
        function onGamingModeEnabledChanged() {
            root._applyGamingModeState(ShellSettings.Settings.gamingModeEnabled)
        }
    }

    // Gamepad Guide button toggles Game Center overlay
    Connections {
        target: GamingShell.GamepadManager
        enabled: ShellSettings.Settings.gamingModeEnabled
        function onButtonPressed(button, gamepadIndex) {
            if (button === GamingShell.GamepadManager.ButtonGuide) {
                root.gameCenterOpen = !root.gameCenterOpen
            }
        }
    }

    Component.onCompleted: {
        root._applyGamingModeState(ShellSettings.Settings.gamingModeEnabled)
        folio.FolioSettings.load();
        folio.FavouritesModel.load();
        folio.PageListModel.load();
    }

    property MobileShell.MaskManager maskManager: MobileShell.MaskManager {
        height: root.height
        width: root.width
    }

    property MobileShell.MaskManager frontMaskManager: MobileShell.MaskManager {
        height: root.height
        width: root.width
    }

    // wallpaper blur layer
    MobileShell.BlurEffect {
        id: wallpaperBlur
        active: folio.FolioSettings.wallpaperBlurEffect > 0
        anchors.fill: parent
        sourceLayer: Plasmoid.wallpaperGraphicsObject
        maskSourceLayer: folio.FolioSettings.wallpaperBlurEffect > 1 ? maskManager.maskLayer : null

        fullBlur: Math.min(1,
                           Math.max(
                               1 - homeScreen.contentOpacity,
                               // Convergence: no blur for popup drawer
                               ShellSettings.Settings.convergenceModeEnabled ? 0 : folio.HomeScreenState.appDrawerOpenProgress * 2,
                               folio.HomeScreenState.searchWidgetOpenProgress * 1.5, // blur faster during swipe
                               folio.HomeScreenState.folderOpenProgress
                           )
        )
    }

    WindowPlugin.WindowMaximizedTracker {
        id: windowMaximizedTracker
        screenGeometry: Plasmoid.containment.screenGeometry
    }

    // In gaming mode, reopen Game Center when the last window goes away
    // so the user is never stranded on a bare wallpaper.
    Connections {
        target: windowMaximizedTracker
        enabled: ShellSettings.Settings.gamingModeEnabled
        function onShowingWindowChanged() {
            if (!windowMaximizedTracker.showingWindow && !root.gameCenterOpen) {
                root.gameCenterOpen = true
            }
        }
    }

    // Close app drawer when a new window appears
    Connections {
        target: WindowPlugin.WindowUtil
        function onWindowCreated() {
            if (folio.HomeScreenState.viewState === Folio.HomeScreenState.AppDrawerView) {
                folio.HomeScreenState.closeAppDrawer();
            }
        }
    }

    function homeAction() {
        const isInWindow = (!WindowPlugin.WindowUtil.isShowingDesktop && windowMaximizedTracker.showingWindow);

        // Always close action drawer
        if (MobileShellState.ShellDBusClient.isActionDrawerOpen) {
            MobileShellState.ShellDBusClient.closeActionDrawer();
        }

        if (ShellSettings.Settings.gamingModeEnabled) {
            // In gaming mode Home/Menu should reopen the Game Center overlay.
            root.gameCenterOpen = true;
            return;
        }

        if (ShellSettings.Settings.convergenceModeEnabled) {
            // Convergence: toggle the app drawer as a layer-shell overlay
            // without disturbing open windows.
            switch (folio.HomeScreenState.viewState) {
                case Folio.HomeScreenState.AppDrawerView:
                    folio.HomeScreenState.closeAppDrawer();
                    break;
                case Folio.HomeScreenState.FolderView:
                    folio.HomeScreenState.closeFolder();
                    break;
                case Folio.HomeScreenState.SearchWidgetView:
                    folio.HomeScreenState.closeSearchWidget();
                    break;
                case Folio.HomeScreenState.SettingsView:
                    folio.HomeScreenState.closeSettingsView();
                    break;
                default:
                    folio.HomeScreenState.openAppDrawer();
                    break;
            }
            return;
        }

        if (isInWindow) {
            folio.HomeScreenState.closeFolder();
            folio.HomeScreenState.closeSearchWidget();
            folio.HomeScreenState.closeAppDrawer();
            folio.HomeScreenState.goToPage(0, false);

            WindowPlugin.WindowUtil.minimizeAll();

            // Always ensure settings view is closed
            if (folio.HomeScreenState.viewState == Folio.HomeScreenState.SettingsView) {
                folio.HomeScreenState.closeSettingsView();
            }

        } else { // If we are already on the homescreen
            switch (folio.HomeScreenState.viewState) {
                case Folio.HomeScreenState.PageView:
                    if (folio.HomeScreenState.currentPage === 0) {
                        folio.HomeScreenState.openAppDrawer();
                    } else {
                        folio.HomeScreenState.goToPage(0, false);
                    }
                    break;
                case Folio.HomeScreenState.AppDrawerView:
                    folio.HomeScreenState.closeAppDrawer();
                    break;
                case Folio.HomeScreenState.SearchWidgetView:
                    folio.HomeScreenState.closeSearchWidget();
                    break;
                case Folio.HomeScreenState.FolderView:
                    folio.HomeScreenState.closeFolder();
                    break;
                case Folio.HomeScreenState.SettingsView:
                    folio.HomeScreenState.closeSettingsView();
                    break;
            }
        }
    }

    Plasmoid.onActivated: homeAction()

    Rectangle {
        id: appDrawerBackground
        anchors.fill: parent
        // Convergence: no scrim (popup has own background); mobile: dark scrim
        color: ShellSettings.Settings.convergenceModeEnabled
            ? "transparent"
            : Qt.rgba(0, 0, 0, 0.6)

        opacity: folio.HomeScreenState.appDrawerOpenProgress
    }

    Rectangle {
        id: searchWidgetBackground
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)

        opacity: folio.HomeScreenState.searchWidgetOpenProgress
    }

    Rectangle {
        id: settingsViewBackground
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)

        opacity: folio.HomeScreenState.settingsOpenProgress
    }

    // Dock overlay window — renders the favourites bar above application
    // windows in convergence mode.  LayerTop sits above normal windows but
    // below LayerOverlay (notifications, volume OSD).  The exclusive zone
    // that reserves screen space is handled by the dockSpaceReserver in the
    // task panel containment; this window only provides the visible dock.
    Window {
        id: dockOverlay
        readonly property bool active: ShellSettings.Settings.convergenceModeEnabled && !ShellSettings.Settings.gamingModeEnabled

        visible: active
        opacity: active ? 1 : 0
        color: "transparent"
        width: Screen.width
        height: MobileShell.Constants.convergenceDockHeight

        LayerShell.Window.scope: "dock-overlay"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: shouldReserveSpace ? dockHeight : -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

        // Auto-hide: slide dock content off-screen when a window is
        // maximized.  The reveal strip at the screen edge brings it back.
        property real dockOffset: 0
        readonly property real dockHeight: MobileShell.Constants.convergenceDockHeight

        // Height of the input-receive strip kept at the screen edge when
        // the dock is hidden.  Matches the navigation panel convention.
        readonly property real revealStripHeight: MobileShell.Constants.convergenceDockRevealHeight

        // True once the hover-reveal timer fires; cleared on hover-exit.
        property bool hoverRevealing: false

        readonly property bool shouldHide: ShellSettings.Settings.autoHidePanelsEnabled
                                              && windowMaximizedTracker.showingWindow && !hoverRevealing
        readonly property bool shouldReserveSpace: ShellSettings.Settings.autoHidePanelsEnabled
                                                   && windowMaximizedTracker.showingWindow && hoverRevealing

        function updateInputRegion() {
            if (shouldHide && dockOffset >= dockHeight) {
                MobileShell.ShellUtil.setInputRegion(dockOverlay,
                    Qt.rect(0, dockOverlay.height - revealStripHeight,
                            dockOverlay.width, revealStripHeight))
            } else {
                MobileShell.ShellUtil.setInputRegion(dockOverlay, Qt.rect(0, 0, 0, 0))
            }
        }

        onActiveChanged: {
            hoverRevealTimer.stop()
            hoverRevealing = false
            dockOffset = shouldHide ? dockHeight : 0
            updateInputRegion()
        }

        onShouldHideChanged: {
            if (shouldHide) {
                dockOffset = dockHeight
            } else {
                dockOffset = 0
            }
            updateInputRegion()
        }

        // Narrow the input region to a strip at the screen edge when hidden
        // so that app controls near the bottom edge are not accidentally
        // intercepted.  Mirrors the same pattern used by NavigationPanel.
        onDockOffsetChanged: {
            updateInputRegion()
        }
        onWidthChanged: updateInputRegion()
        onHeightChanged: updateInputRegion()

        // Delay reveal briefly so a quick edge graze does not pop the
        // dock up mid-interaction with the underlying application.
        Timer {
            id: hoverRevealTimer
            interval: Kirigami.Units.shortDuration
            repeat: false
            onTriggered: dockOverlay.hoverRevealing = true
        }

        HoverHandler {
            id: dockHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    hoverRevealTimer.start()
                } else {
                    hoverRevealTimer.stop()
                    dockOverlay.hoverRevealing = false
                }
            }
        }

        Behavior on dockOffset {
            NumberAnimation {
                easing.type: Easing.InOutCubic
                duration: Kirigami.Units.longDuration
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        Rectangle {
            anchors.fill: parent
            visible: !dockOverlay.shouldHide || dockOverlay.dockOffset < dockOverlay.dockHeight
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            color: Kirigami.Theme.backgroundColor
        }

        FavouritesBar {
            id: dockOverlayBar
            anchors.fill: parent
            folio: root.folio
            maskManager: root.maskManager
            homeScreen: folioHomeScreen
            suppressRunningTasks: runningAppsPanel.visible
            transform: Translate { y: dockOverlay.dockOffset }
            // Dock is an opaque panel — use Window colorset so all content
            // (labels, hover highlights, icon tints) follows the system theme
            // instead of the containment's Complementary wallpaper context.
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
        }
    }

    // App-drawer overlay — renders the popup drawer above application
    // windows in convergence mode.  Same pattern as the dock overlay:
    // a fullscreen layer-shell surface at LayerTop so that it appears
    // over normal windows without minimizing them.
    Window {
        id: drawerOverlay
        visible: ShellSettings.Settings.convergenceModeEnabled
                 && !ShellSettings.Settings.gamingModeEnabled
                 && folio.HomeScreenState.appDrawerOpenProgress > 0
        color: "transparent"
        width: Screen.width
        height: Screen.height

        LayerShell.Window.scope: "drawer-overlay"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                                   | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

        // Click outside the popup to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: folio.HomeScreenState.closeAppDrawer()
        }

        AppDrawer {
            id: overlayDrawer
            folio: root.folio
            homeScreen: folioHomeScreen

            readonly property real popupWidth: Math.min(Kirigami.Units.gridUnit * 28, parent.width * 0.5)
            readonly property real popupHeight: Math.min(Kirigami.Units.gridUnit * 32, parent.height * 0.7)
            readonly property real dockHeight: MobileShell.Constants.convergenceDockHeight

            width: popupWidth
            height: popupHeight

            opacity: folio.HomeScreenState.appDrawerOpenProgress < 0.5
                ? 0 : (folio.HomeScreenState.appDrawerOpenProgress - 0.5) * 2

            property real animationY: (1 - folio.HomeScreenState.appDrawerOpenProgress) * (Kirigami.Units.gridUnit * 2)

            x: Kirigami.Units.smallSpacing
            y: (opacity > 0)
                ? parent.height - dockHeight - popupHeight - Kirigami.Units.smallSpacing + animationY
                : parent.height

            headerHeight: Math.round(Kirigami.Units.gridUnit * 3)
            headerItem: AppDrawerHeader {
                id: overlayDrawerHeader
                folio: root.folio
                onReleaseFocusRequested: overlayDrawer.forceActiveFocus()
            }

            Keys.onPressed: (event) => {
                if (event.text.trim().length > 0) {
                    overlayDrawerHeader.addSearchText(event.text);
                    overlayDrawerHeader.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                           || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    overlayDrawerHeader.forceActiveFocus();
                    event.accepted = true;
                }
            }

            Connections {
                target: folio.HomeScreenState

                function onAppDrawerOpened() {
                    folio.ApplicationListSearchModel.categoryFilter = ""
                    overlayDrawer.forceActiveFocus()
                }
            }
        }

        // Drop shadow rendered separately so categoryPanel itself needs no
        // layer FBO (which would rasterize and blur the icons inside).
        Rectangle {
            id: categoryPanelShadow
            width: categoryPanel.width
            height: categoryPanel.height
            x: categoryPanel.x
            y: categoryPanel.y
            radius: categoryPanel.radius
            color: categoryPanel.color
            opacity: categoryPanel.opacity
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 2
                radius: 12
                samples: 25
                color: Qt.rgba(0, 0, 0, 0.4)
            }
        }

        CategoryPanel {
            id: categoryPanel
            folio: root.folio

            width: Kirigami.Units.gridUnit * 9
            height: overlayDrawer.popupHeight
            x: overlayDrawer.x + overlayDrawer.width + Kirigami.Units.smallSpacing
            y: overlayDrawer.y
            opacity: overlayDrawer.opacity

            onCategorySelected: (catId) => {
                folio.ApplicationListSearchModel.categoryFilter = catId
                overlayDrawerHeader.clearSearchText()
            }
        }

        // Drop shadow rendered separately so powerPanel itself needs no layer FBO,
        // which would rasterize and blur the icons inside.
        Rectangle {
            id: powerPanelShadow
            width: powerPanel.width
            height: powerPanel.height
            x: powerPanel.x
            y: powerPanel.y
            radius: powerPanel.radius
            color: powerPanel.color
            opacity: powerPanel.opacity
            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                horizontalOffset: 0
                verticalOffset: 2
                radius: 12
                samples: 25
                color: Qt.rgba(0, 0, 0, 0.4)
            }
        }

        Rectangle {
            id: powerPanel

            // Width: just enough for one icon button + side margins
            readonly property real tileSize: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.largeSpacing

            width: tileSize
            height: overlayDrawer.popupHeight
            x: runningAppsPanel.visible
                ? runningAppsPanel.x + runningAppsPanel.width + Kirigami.Units.smallSpacing
                : categoryPanel.x + categoryPanel.width + Kirigami.Units.smallSpacing
            y: overlayDrawer.y
            opacity: overlayDrawer.opacity
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.backgroundColor

            MouseArea {
                anchors.fill: parent
            }

            KCoreAddons.KUser {
                id: kuser
            }

            SessionManagement {
                id: powerSession
            }

            // Close button anchored to top — smaller than power icons
            Rectangle {
                id: closeButton
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                height: Kirigami.Units.iconSizes.smallMedium + 2 * Kirigami.Units.smallSpacing
                radius: Kirigami.Units.cornerRadius
                color: closeArea.containsPress
                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                    : closeArea.containsMouse
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                        : "transparent"
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: width
                    source: "window-close-symbolic"
                    active: closeArea.containsMouse
                }
                PlasmaComponents.ToolTip {
                    text: i18n("Close")
                    visible: closeArea.containsMouse
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: folio.HomeScreenState.closeAppDrawer()
                }
            }

            // Separator below close button
            Rectangle {
                anchors.top: closeButton.bottom
                anchors.topMargin: Kirigami.Units.smallSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                height: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
            }

            // Power buttons centred vertically in the panel
            Column {
                id: powerColumn
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    width: parent.width
                    height: width
                    radius: Kirigami.Units.cornerRadius
                    color: lockArea.containsPress
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                        : lockArea.containsMouse
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                            : "transparent"
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        source: "system-lock-screen"
                        active: lockArea.containsMouse
                    }
                    PlasmaComponents.ToolTip {
                        text: i18n("Lock Screen")
                        visible: lockArea.containsMouse
                    }
                    MouseArea {
                        id: lockArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerSession.lock()
                            folio.HomeScreenState.closeAppDrawer()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: width
                    radius: Kirigami.Units.cornerRadius
                    color: rebootArea.containsPress
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                        : rebootArea.containsMouse
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                            : "transparent"
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        source: "system-reboot"
                        active: rebootArea.containsMouse
                    }
                    PlasmaComponents.ToolTip {
                        text: i18n("Restart")
                        visible: rebootArea.containsMouse
                    }
                    MouseArea {
                        id: rebootArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            folio.HomeScreenState.closeAppDrawer()
                            powerSession.requestReboot()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: width
                    radius: Kirigami.Units.cornerRadius
                    color: shutdownArea.containsPress
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                        : shutdownArea.containsMouse
                            ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                            : "transparent"
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: Kirigami.Units.iconSizes.medium
                        height: width
                        source: "system-shutdown"
                        active: shutdownArea.containsMouse
                    }
                    PlasmaComponents.ToolTip {
                        text: i18n("Shut Down")
                        visible: shutdownArea.containsMouse
                    }
                    MouseArea {
                        id: shutdownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            folio.HomeScreenState.closeAppDrawer()
                            powerSession.requestShutdown()
                        }
                    }
                }
            }

            // Separator above user avatar
            Rectangle {
                anchors.bottom: userSection.top
                anchors.bottomMargin: Kirigami.Units.smallSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                height: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
            }

            // User avatar anchored to bottom — tooltip shows name, click opens user settings
            Rectangle {
                id: userSection
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                height: width
                radius: Kirigami.Units.cornerRadius
                color: userArea.containsPress
                    ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                    : userArea.containsMouse
                        ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)
                        : "transparent"

                KirigamiAddonsComponents.Avatar {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.medium
                    height: width
                    source: kuser.faceIconUrl
                    name: kuser.fullName || kuser.loginName
                }
                PlasmaComponents.ToolTip {
                    text: kuser.fullName || kuser.loginName
                    visible: userArea.containsMouse
                }
                MouseArea {
                    id: userArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        KCM.KCMLauncher.openSystemSettings("kcm_users")
                        folio.HomeScreenState.closeAppDrawer()
                    }
                }
            }
        }

        RunningAppsPanel {
            id: runningAppsPanel
            folio: root.folio

            x: categoryPanel.x + categoryPanel.width + Kirigami.Units.smallSpacing
            y: overlayDrawer.y
            width: Math.max(0, parent.width - x - powerPanel.width - Kirigami.Units.smallSpacing * 2)
            height: overlayDrawer.popupHeight
            opacity: overlayDrawer.opacity
            visible: hasTasks && opacity > 0

            onTaskActivated: folio.HomeScreenState.closeAppDrawer()
        }
    }

    // Game Center overlay — full-screen grid of games shown when gaming mode
    // is active.  Sits at LayerTop so it covers running application windows
    // without going above system notifications.
    GameCenterOverlay {
        id: gameCenterOverlay
        folio: root.folio
        visible: ShellSettings.Settings.gamingModeEnabled && root.gameCenterOpen

        onGameStarted: root.gameCenterOpen = false
        onDismissRequested: {
            root.gameCenterOpen = false
            if (ShellSettings.Settings.gamingDismissHintEnabled) {
                root.showGameCenterHint = true
                gameCenterHintTimer.restart()
            }
        }
    }

    // Small persistent button at the top-right corner of the screen that lets
    // the user return to the Game Center after launching a game.
    // Keep the Loader active for the full duration of gaming mode so the
    // opacity Behavior in GamingHUD can animate both fade-in and fade-out.
    //
    // Hide the HUD while a game window covers the screen. A mapped LayerShell
    // surface prevents KWin from using DRM direct scanout for the fullscreen
    // game window. Setting showing=false triggers the opacity fade-out and then
    // sets visible=false, which unmaps the Wayland surface and lets KWin bypass
    // the compositor render loop entirely for the game frame.
    Loader {
        active: ShellSettings.Settings.gamingModeEnabled
        sourceComponent: GamingHUD {
            visible: showing
            showing: !root.gameCenterOpen && !windowMaximizedTracker.showingWindow
            onOpenRequested: root.gameCenterOpen = true
        }
    }

    Rectangle {
        id: gameCenterHint
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Kirigami.Units.gridUnit * 2
        visible: root.showGameCenterHint && ShellSettings.Settings.gamingDismissHintEnabled
        opacity: visible ? 1 : 0
        z: 2000
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.65)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2)

        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
        }

        implicitWidth: hintText.implicitWidth + Kirigami.Units.gridUnit * 2
        implicitHeight: hintText.implicitHeight + Kirigami.Units.largeSpacing

        PlasmaComponents.Label {
            id: hintText
            anchors.centerIn: parent
            text: i18n("Gaming mode is still on. Use Home or the gamepad icon to reopen Game Center.")
            color: "white"
            wrapMode: Text.WordWrap
            width: Math.min(root.width * 0.8, Kirigami.Units.gridUnit * 30)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MobileShell.HomeScreen {
        id: homeScreen
        anchors.fill: parent

        plasmoidItem: root
        onResetHomeScreenPosition: {
            // NOTE: empty, because this is handled by homeAction()
        }

        onHomeTriggered: root.homeAction()

        contentItem: Item {

            // homescreen component
            FolioHomeScreen {
                id: folioHomeScreen
                folio: root.folio
                maskManager: root.maskManager
                anchors.fill: parent

                topMargin: homeScreen.topMargin
                bottomMargin: homeScreen.bottomMargin
                leftMargin: homeScreen.leftMargin
                rightMargin: homeScreen.rightMargin

                // Ensure is the focused item at start
                Component.onCompleted: forceActiveFocus()

                onWallpaperSelectorTriggered: wallpaperSelectorLoader.active = true
            }
        }
    }

    // top blur layer for items on top of the base homescreen
    MobileShell.BlurEffect {
        id: homescreenBlur
        anchors.fill: parent
        active: folio.FolioSettings.wallpaperBlurEffect > 1 && ((delegateDragItem.visible && folio.HomeScreenState.dragState.dropDelegate.type === Folio.FolioDelegate.Folder) || wallpaperSelectorLoader.active)
        visible: active
        fullBlur: 0

        sourceLayer: homeScreenLayer
        maskSourceLayer: frontMaskManager.maskLayer

        // stacking both wallpaper and homescreen layers so we can blur them in one pass
        Item {
            id: homeScreenLayer
            anchors.fill: parent
            opacity: 0

            // wallpaper blur
            ShaderEffectSource {
                anchors.fill: parent

                textureSize: homescreenBlur.textureSize
                sourceItem: Plasmoid.wallpaperGraphicsObject
                hideSource: false
            }

            // homescreen blur
            ShaderEffectSource {
                anchors.fill: parent

                textureSize: homescreenBlur.textureSize
                sourceItem: homeScreen
                hideSource: false
            }
        }
    }

    // drag and drop component
    DelegateDragItem {
        id: delegateDragItem
        folio: root.folio
        maskManager: root.frontMaskManager
    }

    // drag and drop for widgets
    WidgetDragItem {
        id: widgetDragItem
        folio: root.folio
    }

    // loader for wallpaper selector
    Loader {
        id: wallpaperSelectorLoader
        anchors.fill: parent
        asynchronous: true
        active: false

        onLoaded: {
            wallpaperSelectorLoader.item.open();
        }

        sourceComponent: MobileShell.WallpaperSelector {
            maskManager: root.frontMaskManager
            horizontal: root.width > root.height
            edge: horizontal ? Qt.LeftEdge : Qt.BottomEdge
            topMargin: horizontal ? folioHomeScreen.topMargin : 0
            bottomMargin: horizontal ? 0 : folioHomeScreen.bottomMargin
            leftMargin: horizontal ? folioHomeScreen.leftMargin : 0
            rightMargin: horizontal ? folioHomeScreen.rightMargin : 0
            onClosed: {
                wallpaperSelectorLoader.active = false;
            }

            onWallpaperSettingsRequested: {
                close();
                folioHomeScreen.openConfigure();
            }
        }
    }
}

