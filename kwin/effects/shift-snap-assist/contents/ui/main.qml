// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2
//
// SHIFT Snap Assist — KWin declarative SceneEffect
//
// Presents a floating panel of layout preset buttons.
// Activated by:
//   1. Meta+Shift+S keyboard shortcut
//   2. The SHIFT decoration invoking the kglobalaccel shortcut on maximize-hover
//
// When a preset is clicked, the active window's frameGeometry is set to the
// chosen zone (with outer gaps applied).  If a second zone is non-empty a
// "snap assist" strip shows recently-used windows as targets.

import QtQuick
import QtQuick.Layouts
import org.kde.kwin as KWinComponents

KWinComponents.SceneEffect {
    id: effect

    // ── Visibility ────────────────────────────────────────────────────────

    // The effect starts invisible; toggle via shortcut.
    // SceneEffect.visible controls whether delegates are painted.

    KWinComponents.ShortcutHandler {
        name: "SHIFT Snap Assist"
        text: "SHIFT Snap Assist: Show snap layout picker"
        sequence: "Meta+Shift+S"
        onActivated: effect.visible = !effect.visible
    }

    // Auto-hide when a window starts being moved (decoration hover path)
    Connections {
        target: KWinComponents.Workspace
        function onActiveWindowChanged() {
            // Keep visible so decoration can re-trigger
        }
    }

    // ── Gap constant (must match shift-tiling) ────────────────────────────
    readonly property int outerGap: 8

    // ── Layout presets ────────────────────────────────────────────────────
    // Each preset is an array of zone descriptors:
    //   { x, y, w, h }  in relative [0..1] coordinates (of work area).
    // The first zone is where the ACTIVE window will be placed.
    // Remaining zones are shown as snap-assist targets.

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

        // Transparent background — clicks outside the panel pass through
        color: "transparent"

        // The panel sits at the top-right of the screen
        SnapPanel {
            anchors {
                top: parent.top
                topMargin: 48   // below typical titlebar height
                right: parent.right
                rightMargin: 16
            }

            screen: KWinComponents.SceneView.screen
        }
    }

    // ── Snap panel component ──────────────────────────────────────────────

    component SnapPanel: Rectangle {
        id: panel

        required property var screen

        width: presetsRow.implicitWidth + 32
        height: presetsRow.implicitHeight + 40

        color: Qt.rgba(0.10, 0.12, 0.18, 0.92)
        radius: 12
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)

        // Drop shadow via a blurred copy underneath
        Rectangle {
            anchors { fill: parent; margins: -6 }
            color: Qt.rgba(0, 0, 0, 0.35)
            radius: parent.radius + 6
            z: -1
            layer.enabled: true
            layer.effect: Item {}  // placeholder — real blur requires Qt.labs.platform
        }

        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 12

            Text {
                text: "Snap layouts"
                color: "#b0b8d4"
                font.pixelSize: 11
                font.letterSpacing: 0.8
                font.capitalization: Font.AllUppercase
            }

            Row {
                id: presetsRow
                spacing: 10

                Repeater {
                    model: effect.presets

                    PresetButton {
                        preset: modelData
                        screen: panel.screen
                        onClicked: {
                            effect.visible = false;
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

        width: 64
        height: 44

        color: hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        radius: 6
        border.width: 1
        border.color: hovered ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.12)

        property bool hovered: false

        Behavior on color { ColorAnimation { duration: 80 } }

        // Mini zone diagram
        Repeater {
            model: btn.preset.zones

            Rectangle {
                x:      Math.round(modelData.x * (btn.width  - 2)) + 1
                y:      Math.round(modelData.y * (btn.height - 2)) + 1
                width:  Math.round(modelData.w * (btn.width  - 2)) - 1
                height: Math.round(modelData.h * (btn.height - 2)) - 1
                color: index === 0 ? Qt.rgba(0.44, 0.62, 1.0, 0.85)
                                   : Qt.rgba(0.44, 0.62, 1.0, 0.35)
                border.width: 0
                radius: 2
            }
        }

        HoverHandler {
            onHoveredChanged: {
                btn.hovered = hovered;
                if (hovered) {
                    // Show outline on screen for the first zone
                    const win = KWinComponents.Workspace.activeWindow;
                    if (!win || !win.output) return;
                    const desktop = win.desktops.length > 0 ? win.desktops[0] : null;
                    if (!desktop) return;
                    const area = KWinComponents.Workspace.clientArea(
                        KWinComponents.Workspace.MaximizeArea, win.output, desktop);
                    const zone = btn.preset.zones[0];
                    const g = effect.outerGap;
                    KWinComponents.Workspace.showOutline(Qt.rect(
                        area.x + Math.round(zone.x * area.width)  + g,
                        area.y + Math.round(zone.y * area.height) + g,
                        Math.round(zone.w * area.width)  - 2 * g,
                        Math.round(zone.h * area.height) - 2 * g
                    ));
                } else {
                    KWinComponents.Workspace.hideOutline();
                }
            }
        }

        TapHandler {
            onTapped: {
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
                KWinComponents.Workspace.hideOutline();
                effect.applyZone(win, btn.preset.zones[0], area);
                btn.clicked();
            }
        }
    }
}
