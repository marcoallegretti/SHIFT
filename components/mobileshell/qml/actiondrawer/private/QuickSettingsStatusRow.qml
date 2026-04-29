// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick 2.15
import QtQuick.Layouts 1.1

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

/**
 * Full-width management row (Wi-Fi, Bluetooth, Audio, Battery) shown in
 * convergence mode.  Two interaction zones:
 *   - Left toggle pill: icon + indicator dot, tap toggles the service.
 *   - Right detail area: name + status + chevron, tap opens detail popup.
 */
Item {
    id: root

    required property string text
    required property string status
    required property string icon
    required property bool enabled
    required property var toggleFunction

    signal detailClicked()

    implicitHeight: Kirigami.Units.gridUnit * 3.6

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Button

    readonly property int rowRadius: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
    readonly property color enabledBg: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.25)
    readonly property color enabledBgHover: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.32)
    readonly property color enabledBgPressed: mixColor(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, 0.12)
    readonly property color enabledBorder: Qt.darker(Kirigami.Theme.highlightColor, 1.25)

    readonly property color disabledBg: Kirigami.Theme.alternateBackgroundColor
    readonly property color disabledBgHover: mixColor(Kirigami.Theme.alternateBackgroundColor, Kirigami.Theme.textColor, 0.06)
    readonly property color disabledBgPressed: Qt.darker(disabledBg, 1.1)
    readonly property color disabledBorder: {
        let bg = Kirigami.Theme.backgroundColor;
        let fg = Kirigami.Theme.textColor;
        if (Kirigami.ColorUtils.brightnessForColor(bg) === Kirigami.ColorUtils.Light) {
            return Kirigami.ColorUtils.linearInterpolation(bg, fg, 0.2);
        } else {
            return Kirigami.ColorUtils.linearInterpolation(bg, fg, 0.1);
        }
    }

    function mixColor(base, overlay, ratio) {
        return Qt.rgba(
            base.r + (overlay.r - base.r) * ratio,
            base.g + (overlay.g - base.g) * ratio,
            base.b + (overlay.b - base.b) * ratio,
            base.a + (overlay.a - base.a) * ratio)
    }

    MobileShell.HapticsEffect { id: haptics }

    // ── Outer card ──────────────────────────────────────────────────────
    // Shadow
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        radius: root.rowRadius
        color: Qt.rgba(0, 0, 0, root.enabled ? 0.12 : 0.08)
    }

    // Card background — always neutral base (the toggle pill carries the
    // enabled highlight, not the whole row).
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: root.rowRadius
        border.pixelAligned: false
        border.width: 1
        border.color: root.disabledBorder
        color: root.disabledBg
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        // ── Toggle pill (left zone) ─────────────────────────────────
        Item {
            id: togglePill
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.height - Kirigami.Units.smallSpacing * 2
            Layout.fillHeight: true

            Rectangle {
                id: pillBg
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                border.pixelAligned: false
                border.width: 1
                border.color: root.enabled ? root.enabledBorder : root.disabledBorder
                color: {
                    if (root.enabled) {
                        if (toggleMouse.pressed) {
                            return root.enabledBgPressed;
                        }
                        return toggleMouse.containsMouse ? root.enabledBgHover : root.enabledBg;
                    }
                    if (toggleMouse.pressed) {
                        return root.disabledBgPressed;
                    }
                    return toggleMouse.containsMouse ? root.disabledBgHover : root.disabledBg;
                }

                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration }
                }
            }

            // Scale on press
            property real zoomScale: (ShellSettings.Settings.animationsEnabled && toggleMouse.pressed) ? 0.9 : 1
            Behavior on zoomScale {
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutExpo }
            }
            transform: Scale {
                origin.x: togglePill.width / 2
                origin.y: togglePill.height / 2
                xScale: togglePill.zoomScale
                yScale: togglePill.zoomScale
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    source: root.icon
                }

                // Indicator bar
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: root.enabled ? Kirigami.Units.smallSpacing * 3 : Kirigami.Units.smallSpacing * 1.5
                    height: Math.max(2, Math.round(Kirigami.Units.devicePixelRatio))
                    radius: height / 2
                    color: root.enabled ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                    opacity: root.enabled ? 1.0 : 0.4

                    Behavior on width {
                        NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: haptics.buttonVibrate()
                onClicked: {
                    if (root.toggleFunction) root.toggleFunction();
                }
            }
        }

        // ── Detail area (right zone) ────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Hover/press highlight
            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius
                color: detailMouse.pressed ? Qt.rgba(Kirigami.Theme.textColor.r,
                                                      Kirigami.Theme.textColor.g,
                                                      Kirigami.Theme.textColor.b, 0.06)
                     : detailMouse.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r,
                                                           Kirigami.Theme.textColor.g,
                                                           Kirigami.Theme.textColor.b, 0.03)
                     : "transparent"
            }

            MouseArea {
                id: detailMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: haptics.buttonVibrate()
                onClicked: root.detailClicked()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    MobileShell.MarqueeLabel {
                        Layout.fillWidth: true
                        inputText: root.text
                        font.weight: Font.Bold
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                    }

                    MobileShell.MarqueeLabel {
                        Layout.fillWidth: true
                        inputText: root.status ? root.status : (root.enabled ? i18n("On") : i18n("Off"))
                        opacity: 0.6
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                    }
                }

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    source: "go-next-symbolic"
                    opacity: 0.5
                }
            }
        }
    }
}
