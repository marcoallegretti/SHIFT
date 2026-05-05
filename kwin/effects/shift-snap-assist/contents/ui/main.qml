// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2
//
// SHIFT Snap Assist — KWin declarative SceneEffect
//
// Presents a floating panel of layout preset buttons.
// Activated by:
//   1. Meta+Shift+S keyboard shortcut
//   2. Hovering the maximize button in convergence mode while dynamic tiling is off
//
// When a preset is clicked, the active window's frameGeometry is set to the
// chosen zone (with outer gaps applied).

import QtQuick
import QtQuick.Layouts
import org.kde.kwin as KWinComponents
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

KWinComponents.SceneEffect {
    id: effect

    visible: false

    readonly property bool snapLayoutsEligible: ShellSettings.Settings.convergenceModeEnabled
                                             && !ShellSettings.Settings.gamingModeEnabled
                                             && !ShellSettings.Settings.dynamicTilingEnabled
    readonly property int hoverBarHeight: 30
    readonly property int decorationButtonSize: 16
    readonly property int decorationButtonSpacing: 8
    readonly property int decorationButtonSideMargin: 12
    readonly property int maximizeButtonPadding: 4
    readonly property int hoverTimerInterval: 75
    readonly property int hoverDwellTicks: 14
    readonly property int hoverMoveTolerance: 5
    readonly property int hoverCooldownMs: 1200
    readonly property int panelDismissMargin: 24
    readonly property int panelScreenMargin: 8
    readonly property int panelCursorGap: 12
    readonly property int panelCursorRightBias: 34
    property var hoverWindowId: null
    property int hoverTicks: 0
    property string hoverWindowStateKey: ""
    property bool hoverSuppressedUntilLeave: false
    property point hoverAnchorPos: Qt.point(0, 0)
    property double hoverCooldownUntil: 0
    property var panelAnchorPos: Qt.point(0, 0)
    property string panelAnchorScreenName: ""
    property bool previewVisible: false
    property rect previewGeometry: Qt.rect(0, 0, 0, 0)
    property rect previewArea: Qt.rect(0, 0, 0, 0)
    property var previewZones: []
    property int previewActiveIndex: -1
    property string previewScreenName: ""

    function resetHoverState() {
        hoverWindowId = null;
        hoverTicks = 0;
        hoverWindowStateKey = "";
        hoverSuppressedUntilLeave = false;
        hoverAnchorPos = Qt.point(0, 0);
    }

    function resetHoverCandidate(win) {
        hoverWindowId = win ? win.internalId : null;
        hoverTicks = 1;
        hoverWindowStateKey = win ? windowStateKey(win) : "";
        hoverSuppressedUntilLeave = false;
        hoverAnchorPos = KWinComponents.Workspace.cursorPos;
    }

    function setHoverCooldown() {
        hoverCooldownUntil = Date.now() + hoverCooldownMs;
    }

    function hoverOnCooldown() {
        return Date.now() < hoverCooldownUntil;
    }

    function hoverMovedTooFar() {
        const cursor = KWinComponents.Workspace.cursorPos;
        const dx = cursor.x - hoverAnchorPos.x;
        const dy = cursor.y - hoverAnchorPos.y;
        return dx * dx + dy * dy > hoverMoveTolerance * hoverMoveTolerance;
    }

    function windowStateKey(win) {
        const geometry = win.frameGeometry;
        const maximized = win.maximized === undefined ? "" : win.maximized;
        return maximized + ":" + geometry.x + "," + geometry.y + "," + geometry.width + "x" + geometry.height;
    }

    function hideSnapLayouts() {
        if (visible) {
            setHoverCooldown();
        }
        visible = false;
        resetHoverState();
        panelAnchorScreenName = "";
        hideSnapPreview();
    }

    function showSnapLayouts() {
        const win = KWinComponents.Workspace.activeWindow;
        panelAnchorPos = KWinComponents.Workspace.cursorPos;
        panelAnchorScreenName = win && win.output ? win.output.name : "";
        visible = true;
    }

    function toggleActiveWindowMaximized() {
        const win = KWinComponents.Workspace.activeWindow;
        if (!win || !win.normalWindow || win.fullScreen || !win.maximizable) {
            hideSnapLayouts();
            return;
        }

        const maximize = !win.maximized;
        win.setMaximize(maximize, maximize);
        hideSnapLayouts();
        setHoverCooldown();
    }

    function hideSnapPreview() {
        previewVisible = false;
        previewScreenName = "";
        previewZones = [];
        previewActiveIndex = -1;
        KWinComponents.Workspace.hideOutline();
    }

    function showSnapPreview(preset, activeIndex) {
        const win = KWinComponents.Workspace.activeWindow;
        if (!win || !win.output) {
            hideSnapPreview();
            return;
        }

        const desktop = win.desktops.length > 0 ? win.desktops[0] : null;
        if (!desktop) {
            hideSnapPreview();
            return;
        }

        const area = KWinComponents.Workspace.clientArea(KWinComponents.Workspace.MaximizeArea, win.output, desktop);
        const zone = preset.zones[activeIndex];
        const gap = effect.outerGap;
        previewGeometry = Qt.rect(
            area.x + Math.round(zone.x * area.width) + gap,
            area.y + Math.round(zone.y * area.height) + gap,
            Math.round(zone.w * area.width) - 2 * gap,
            Math.round(zone.h * area.height) - 2 * gap
        );
        previewArea = area;
        previewZones = preset.zones;
        previewActiveIndex = activeIndex;
        previewScreenName = win.output.name;
        previewVisible = true;
        KWinComponents.Workspace.hideOutline();
    }

    function cursorInActiveWindowMaximizeStrip() {
        const win = KWinComponents.Workspace.activeWindow;
        if (!win || !win.normalWindow || win.fullScreen || !win.maximizable) {
            return false;
        }

        const cursor = KWinComponents.Workspace.cursorPos;
        const button = maximizeButtonRect(win);
        if (button.width <= 0 || button.height <= 0) {
            return false;
        }

        return cursor.x >= button.x - effect.maximizeButtonPadding
            && cursor.x <= button.x + button.width + effect.maximizeButtonPadding
            && cursor.y >= button.y - effect.maximizeButtonPadding
            && cursor.y <= button.y + button.height + effect.maximizeButtonPadding;
    }

    function decorationButtonVisible(code) {
        return code === "M" || code === "N" || code === "I" || code === "A" || code === "X";
    }

    function visibleDecorationButtons(sequence) {
        const buttons = [];
        for (let i = 0; i < sequence.length; i++) {
            const code = sequence[i];
            if (decorationButtonVisible(code)) {
                buttons.push(code);
            }
        }
        return buttons;
    }

    function maximizeButtonRect(win) {
        const fg = win.frameGeometry;
        const buttonY = fg.y + Math.round((effect.hoverBarHeight - effect.decorationButtonSize) / 2);
        const leftButtons = visibleDecorationButtons(ShellSettings.KWinSettings.titleButtonsOnLeft);
        const leftIndex = leftButtons.indexOf("A");
        if (leftIndex >= 0) {
            return Qt.rect(
                fg.x + effect.decorationButtonSideMargin + leftIndex * (effect.decorationButtonSize + effect.decorationButtonSpacing),
                buttonY,
                effect.decorationButtonSize,
                effect.decorationButtonSize
            );
        }

        const rightButtons = visibleDecorationButtons(ShellSettings.KWinSettings.titleButtonsOnRight);
        const rightIndex = rightButtons.indexOf("A");
        if (rightIndex >= 0) {
            const rowWidth = rightButtons.length * effect.decorationButtonSize
                + Math.max(0, rightButtons.length - 1) * effect.decorationButtonSpacing;
            return Qt.rect(
                fg.x + fg.width - effect.decorationButtonSideMargin - rowWidth
                    + rightIndex * (effect.decorationButtonSize + effect.decorationButtonSpacing),
                buttonY,
                effect.decorationButtonSize,
                effect.decorationButtonSize
            );
        }

        return Qt.rect(0, 0, 0, 0);
    }

    function cursorInPanel(screen) {
        if (!screen) {
            return false;
        }
        if (panelAnchorScreenName !== "" && panelAnchorScreenName !== screen.name) {
            return false;
        }

        const cursor = KWinComponents.Workspace.cursorPos;
        const panel = panelRect(screen);
        return cursor.x >= panel.x - panelDismissMargin
            && cursor.x <= panel.x + panel.width + panelDismissMargin
            && cursor.y >= panel.y - panelDismissMargin
            && cursor.y <= panel.y + panel.height + panelDismissMargin;
    }

    function panelRect(screen) {
        const minX = screen.geometry.x + panelScreenMargin;
        const maxX = screen.geometry.x + screen.geometry.width - snapPanelWidth - panelScreenMargin;
        const minY = screen.geometry.y + panelScreenMargin;
        const maxY = screen.geometry.y + screen.geometry.height - snapPanelHeight - panelScreenMargin;
        const wantedX = panelAnchorPos.x - snapPanelWidth + panelCursorRightBias;
        const wantedY = panelAnchorPos.y + panelCursorGap;
        return Qt.rect(
            Math.max(minX, Math.min(maxX, wantedX)),
            Math.max(minY, Math.min(maxY, wantedY)),
            snapPanelWidth,
            snapPanelHeight
        );
    }

    // ── Visibility ────────────────────────────────────────────────────────

    // The effect starts invisible; toggle via shortcut.
    // SceneEffect.visible controls whether delegates are painted.

    KWinComponents.ShortcutHandler {
        name: "SHIFT Snap Assist"
        text: "SHIFT Snap Assist: Show snap layout picker"
        sequence: "Meta+Shift+S"
        onActivated: {
            if (!effect.snapLayoutsEligible) {
                effect.hideSnapLayouts();
                return;
            }
            if (effect.visible) {
                effect.hideSnapLayouts();
            } else {
                effect.showSnapLayouts();
            }
        }
    }

    KWinComponents.ShortcutHandler {
        name: "SHIFT Snap Assist Escape"
        text: "SHIFT Snap Assist: Hide snap layout picker"
        sequence: "Esc"
        onActivated: effect.hideSnapLayouts()
    }

    Timer {
        id: hoverTimer
        interval: effect.hoverTimerInterval
        repeat: true
        running: effect.snapLayoutsEligible

        onTriggered: {
            if (effect.visible) {
                const screen = KWinComponents.Workspace.activeWindow ? KWinComponents.Workspace.activeWindow.output : null;
                if (!effect.cursorInActiveWindowMaximizeStrip() && !effect.cursorInPanel(screen)) {
                    effect.hideSnapLayouts();
                } else {
                    effect.resetHoverState();
                }
                return;
            }

            const win = KWinComponents.Workspace.activeWindow;
            if (!win || !win.normalWindow || win.fullScreen || !win.maximizable) {
                effect.resetHoverState();
                return;
            }

            if (!effect.cursorInActiveWindowMaximizeStrip()) {
                effect.resetHoverState();
                return;
            }

            if (effect.hoverOnCooldown()) {
                effect.resetHoverState();
                return;
            }

            if (effect.hoverWindowId !== win.internalId) {
                effect.resetHoverCandidate(win);
                return;
            }

            if (effect.hoverMovedTooFar()) {
                effect.resetHoverCandidate(win);
                return;
            }

            const stateKey = effect.windowStateKey(win);
            if (stateKey !== effect.hoverWindowStateKey) {
                effect.hoverWindowStateKey = stateKey;
                effect.hoverTicks = 0;
                effect.hoverSuppressedUntilLeave = true;
                effect.setHoverCooldown();
                return;
            }

            if (effect.hoverSuppressedUntilLeave) {
                return;
            }

            effect.hoverTicks++;
            if (effect.hoverTicks >= effect.hoverDwellTicks) {
                effect.showSnapLayouts();
                effect.resetHoverState();
            }
        }
    }

    Connections {
        target: KWinComponents.Workspace
        function onActiveWindowChanged() {
            effect.resetHoverState();
        }
    }

    Connections {
        target: ShellSettings.Settings

        function onConvergenceModeEnabledChanged() {
            if (!effect.snapLayoutsEligible) {
                effect.hideSnapLayouts();
            }
        }

        function onGamingModeEnabledChanged() {
            if (!effect.snapLayoutsEligible) {
                effect.hideSnapLayouts();
            }
        }

        function onDynamicTilingEnabledChanged() {
            if (!effect.snapLayoutsEligible) {
                effect.hideSnapLayouts();
            }
        }
    }

    // ── Gap constant (must match shift-tiling) ────────────────────────────
    readonly property int outerGap: 8

    // ── Layout presets ────────────────────────────────────────────────────
    // Each preset is an array of zone descriptors:
    //   { x, y, w, h }  in relative [0..1] coordinates (of work area).
    // The first zone is where the ACTIVE window will be placed.
    // Remaining zones are currently visual-only.

    readonly property var presets: [
        {
            name: "Half left",
            zones: [
                { x: 0,   y: 0, w: 0.5, h: 1 },
                { x: 0.5, y: 0, w: 0.5, h: 1 }
            ]
        },
        {
            name: "Thirds",
            zones: [
                { x: 0,         y: 0, w: 0.333, h: 1 },
                { x: 0.333,     y: 0, w: 0.334, h: 1 },
                { x: 0.667,     y: 0, w: 0.333, h: 1 }
            ]
        },
        {
            name: "Main + side",
            zones: [
                { x: 0,     y: 0, w: 0.667, h: 1 },
                { x: 0.667, y: 0, w: 0.333, h: 1 }
            ]
        },
        {
            name: "Side + main",
            zones: [
                { x: 0.333, y: 0, w: 0.667, h: 1 },
                { x: 0,     y: 0, w: 0.333, h: 1 }
            ]
        },
        {
            name: "Quad",
            zones: [
                { x: 0,   y: 0,   w: 0.5, h: 0.5 },
                { x: 0.5, y: 0,   w: 0.5, h: 0.5 },
                { x: 0,   y: 0.5, w: 0.5, h: 0.5 },
                { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }
            ]
        },
        {
            name: "Main + two",
            zones: [
                { x: 0,   y: 0,   w: 0.5, h: 1   },
                { x: 0.5, y: 0,   w: 0.5, h: 0.5 },
                { x: 0.5, y: 0.5, w: 0.5, h: 0.5 }
            ]
        }
    ]

    readonly property int snapButtonWidth: 58
    readonly property int snapButtonHeight: 38
    readonly property int snapButtonSpacing: 8
    readonly property int snapPanelHorizontalPadding: 28
    readonly property int snapPanelVerticalPadding: 34
    readonly property int snapPanelWidth: presets.length * snapButtonWidth
                                          + Math.max(0, presets.length - 1) * snapButtonSpacing
                                          + snapPanelHorizontalPadding
    readonly property int snapPanelHeight: snapButtonHeight + snapPanelVerticalPadding + 23

    // Apply a zone (in relative coords) to a window given a work area rect.
    function applyZone(win, zone, area) {
        const g = effect.outerGap;
        win.frameGeometry = Qt.rect(
            area.x + Math.round(zone.x * area.width)  + g,
            area.y + Math.round(zone.y * area.height) + g,
            Math.round(zone.w * area.width)  - 2 * g,
            Math.round(zone.h * area.height) - 2 * g
        );
    }

    // ── Per-screen delegate ───────────────────────────────────────────────

    delegate: Rectangle {
        id: screenDelegate

        readonly property var targetScreen: KWinComponents.SceneView.screen
        readonly property rect popupRect: effect.panelRect(targetScreen)

        color: "transparent"

        KWinComponents.DesktopBackground {
            anchors.fill: parent
            z: -100
            activity: KWinComponents.Workspace.currentActivity
            desktop: KWinComponents.Workspace.currentDesktop
            outputName: screenDelegate.targetScreen.name
        }

        Instantiator {
            model: KWinComponents.WindowFilterModel {
                desktop: KWinComponents.Workspace.currentDesktop
                screenName: screenDelegate.targetScreen.name
                windowModel: stackModel
                minimizedWindows: false
                windowType: ~KWinComponents.WindowFilterModel.Desktop
                            & ~KWinComponents.WindowFilterModel.Notification
                            & ~KWinComponents.WindowFilterModel.CriticalNotification
            }

            KWinComponents.WindowThumbnail {
                wId: model.window.internalId
                x: model.window.x - screenDelegate.targetScreen.geometry.x
                y: model.window.y - screenDelegate.targetScreen.geometry.y
                z: model.window.stackingOrder
                visible: !model.window.hidden
            }

            onObjectAdded: (index, object) => {
                object.parent = screenDelegate
            }
        }

        KWinComponents.WindowModel {
            id: stackModel
        }

        Repeater {
            model: effect.previewVisible && effect.previewScreenName === screenDelegate.targetScreen.name ? effect.previewZones : []

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool activeZone: index === effect.previewActiveIndex
                readonly property int previewGap: effect.outerGap

                x: effect.previewArea.x + Math.round(modelData.x * effect.previewArea.width) + previewGap - screenDelegate.targetScreen.geometry.x
                y: effect.previewArea.y + Math.round(modelData.y * effect.previewArea.height) + previewGap - screenDelegate.targetScreen.geometry.y
                width: Math.max(1, Math.round(modelData.w * effect.previewArea.width) - 2 * previewGap)
                height: Math.max(1, Math.round(modelData.h * effect.previewArea.height) - 2 * previewGap)
                z: activeZone ? 90001 : 90000
                radius: 6
                color: activeZone ? Qt.rgba(0.38, 0.60, 0.98, 0.24)
                                  : Qt.rgba(0.88, 0.92, 1.0, 0.08)
                border.width: activeZone ? 2 : 1
                border.color: activeZone ? Qt.rgba(0.70, 0.82, 1.0, 0.78)
                                         : Qt.rgba(0.86, 0.90, 1.0, 0.26)
            }
        }

        Keys.onEscapePressed: effect.hideSnapLayouts()

        Item {
            id: maximizeForwarder

            readonly property var activeWindow: KWinComponents.Workspace.activeWindow
            readonly property rect buttonRect: activeWindow ? effect.maximizeButtonRect(activeWindow) : Qt.rect(0, 0, 0, 0)

            visible: activeWindow
                     && activeWindow.output
                     && activeWindow.output.name === screenDelegate.targetScreen.name
                     && buttonRect.width > 0
                     && buttonRect.height > 0
            z: 100001
            x: buttonRect.x - effect.maximizeButtonPadding - screenDelegate.targetScreen.geometry.x
            y: buttonRect.y - effect.maximizeButtonPadding - screenDelegate.targetScreen.geometry.y
            width: buttonRect.width + 2 * effect.maximizeButtonPadding
            height: buttonRect.height + 2 * effect.maximizeButtonPadding

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: effect.toggleActiveWindowMaximized()
            }
        }

        SnapPanel {
            id: snapPanel
            visible: effect.panelAnchorScreenName === "" || effect.panelAnchorScreenName === screenDelegate.targetScreen.name
            z: 100000
            x: screenDelegate.popupRect.x - screenDelegate.targetScreen.geometry.x
            y: screenDelegate.popupRect.y - screenDelegate.targetScreen.geometry.y

            screen: KWinComponents.SceneView.screen
        }
    }

    // ── Snap panel component ──────────────────────────────────────────────

    component SnapPanel: Rectangle {
        id: panel

        required property var screen

        width: effect.snapPanelWidth
        height: effect.snapPanelHeight

        color: Qt.rgba(0.08, 0.10, 0.15, 0.82)
        radius: 8
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            color: Qt.rgba(0, 0, 0, 0.22)
            radius: parent.radius
            z: -1
        }

        Column {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            Text {
                text: "Snap layouts"
                color: "#b0b8d4"
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
            }

            Row {
                id: presetsRow
                spacing: effect.snapButtonSpacing

                Repeater {
                    model: effect.presets

                    delegate: PresetButton {
                        required property var modelData

                        preset: modelData
                        screen: panel.screen
                        onClicked: {
                            effect.hideSnapLayouts();
                        }
                    }
                }
            }
        }
    }

    // ── Preset button ─────────────────────────────────────────────────────

    component PresetButton: Rectangle {
        id: btn

        required property var preset
        required property var screen
        signal clicked

        width: effect.snapButtonWidth
        height: effect.snapButtonHeight
        readonly property int previewMargin: 6

        color: hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
        radius: 6
        border.width: 1
        border.color: hovered ? Qt.rgba(0.66, 0.78, 1.0, 0.62) : Qt.rgba(1, 1, 1, 0.14)

        property bool hovered: false

        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
            id: previewFrame
            anchors.fill: parent
            anchors.margins: btn.previewMargin
            color: Qt.rgba(0.06, 0.08, 0.12, 0.72)
            radius: 4
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            clip: true

            Repeater {
                model: btn.preset.zones

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    x: Math.round(modelData.x * previewFrame.width)
                    y: Math.round(modelData.y * previewFrame.height)
                    width: Math.max(4, Math.round(modelData.w * previewFrame.width) - 1)
                    height: Math.max(4, Math.round(modelData.h * previewFrame.height) - 1)
                    color: zoneHover.hovered ? Qt.rgba(0.78, 0.86, 1.0, 0.96)
                                             : (index === 0 ? Qt.rgba(0.46, 0.64, 0.96, 0.96)
                                                           : Qt.rgba(0.58, 0.68, 0.86, 0.48))
                    border.width: 0
                    radius: 2

                    HoverHandler {
                        id: zoneHover
                        onHoveredChanged: {
                            btn.hovered = hovered;
                            if (hovered) {
                                effect.showSnapPreview(btn.preset, index);
                            }
                        }
                    }

                    TapHandler {
                        onTapped: btn.applyZone(modelData)
                    }
                }
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (!hovered) {
                    btn.hovered = false;
                    effect.hideSnapPreview();
                }
            }
        }

        function applyZone(zone) {
                const win = KWinComponents.Workspace.activeWindow;
                if (!win || !win.output) {
                    btn.clicked();
                    return;
                }
                const desktop = win.desktops.length > 0 ? win.desktops[0] : null;
                if (!desktop) {
                    btn.clicked();
                    return;
                }
                const area = KWinComponents.Workspace.clientArea(
                    KWinComponents.Workspace.MaximizeArea, win.output, desktop);
                effect.hideSnapPreview();
                effect.applyZone(win, zone, area);
                btn.clicked();
        }
    }
}
