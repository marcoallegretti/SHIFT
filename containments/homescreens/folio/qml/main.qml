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

import org.kde.layershell 1.0 as LayerShell

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

import "./private"

ContainmentItem {
    id: root
    property Folio.HomeScreen folio: root.plasmoid

    Component.onCompleted: {
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
        visible: ShellSettings.Settings.convergenceModeEnabled
        color: "transparent"
        width: Screen.width
        height: Kirigami.Units.gridUnit * 3

        LayerShell.Window.scope: "dock-overlay"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

        // Auto-hide: slide dock content off-screen when a window is
        // maximized.  A HoverHandler brings it back on mouse proximity.
        property real dockOffset: 0
        readonly property real dockHeight: Kirigami.Units.gridUnit * 3
        readonly property bool dockHovered: dockHoverHandler.hovered
        readonly property bool shouldHide: ShellSettings.Settings.autoHidePanelsEnabled
                                              && windowMaximizedTracker.showingWindow && !dockHovered

        onShouldHideChanged: {
            if (shouldHide) {
                dockOffset = dockHeight
            } else {
                dockOffset = 0
            }
        }

        HoverHandler {
            id: dockHoverHandler
        }

        Behavior on dockOffset {
            NumberAnimation {
                easing.type: dockOverlay.shouldHide ? Easing.InExpo : Easing.OutExpo
                duration: Kirigami.Units.longDuration
            }
        }

        Rectangle {
            anchors.fill: parent
            Kirigami.Theme.inherit: false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            color: Kirigami.Theme.backgroundColor
            transform: Translate { y: dockOverlay.dockOffset }
        }

        FavouritesBar {
            id: dockOverlayBar
            anchors.fill: parent
            folio: root.folio
            maskManager: root.maskManager
            homeScreen: folioHomeScreen
            transform: Translate { y: dockOverlay.dockOffset }
        }
    }

    // App-drawer overlay — renders the popup drawer above application
    // windows in convergence mode.  Same pattern as the dock overlay:
    // a fullscreen layer-shell surface at LayerTop so that it appears
    // over normal windows without minimizing them.
    Window {
        id: drawerOverlay
        visible: ShellSettings.Settings.convergenceModeEnabled
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
            readonly property real dockHeight: Kirigami.Units.gridUnit * 3

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
                    overlayDrawer.forceActiveFocus();
                }
            }
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

