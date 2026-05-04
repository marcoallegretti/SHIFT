// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL 1.2

import QtQuick
import org.kde.kwin.decoration

Decoration {
    id: root
    alpha: true

    // ── Palette ─────────────────────────────────────────────────────────────
    readonly property color activeBar:   "#1a1d2e"
    readonly property color inactiveBar: "#141620"
    readonly property color activeText:  "#f0f0f8"
    readonly property color inactiveText: "#505570"

    readonly property int barHeight:     30
    readonly property int btnSize:       16
    readonly property int btnSpacing:     8
    readonly property int btnSideMargin: 12
    readonly property int cornerRadius:  decoration.client.maximized ? 0 : 8

    Component.onCompleted: {
        borders.top    = barHeight;
        borders.left   = 0;
        borders.right  = 0;
        borders.bottom = 0;

        // Keep titlebar controls available for maximized windows in desktop
        // convergence mode. Mobile mode uses noBorder=true and bypasses this.
        maximizedBorders.top    = barHeight;
        maximizedBorders.left   = 0;
        maximizedBorders.right  = 0;
        maximizedBorders.bottom = 0;
    }

    DecorationOptions {
        id: options
        deco: decoration
    }

    // ── Faint window outline ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.cornerRadius
        border.width: decoration.client.maximized ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    // ── Title bar ────────────────────────────────────────────────────────────
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.barHeight
        radius: root.cornerRadius
        color: decoration.client.active ? root.activeBar : root.inactiveBar
        Behavior on color { ColorAnimation { duration: 120 } }

        // Square off bottom half — only top corners are rounded
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.cornerRadius
            color: parent.color
            visible: !decoration.client.maximized
        }

        // ── Title row ────────────────────────────────────────────────────────
        Item {
            id: titleRow
            anchors.fill: parent

            Row {
                id: leftRow
                spacing: root.btnSpacing
                anchors {
                    left: parent.left
                    leftMargin: root.btnSideMargin
                    verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: options.titleButtonsLeft
                    delegate: ShiftButton { btnType: modelData }
                }
            }

            Text {
                anchors {
                    left: leftRow.right; leftMargin: 6
                    right: rightRow.left; rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                text: decoration.client.caption
                color: decoration.client.active ? root.activeText : root.inactiveText
                font: options.titleFont
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Row {
                id: rightRow
                spacing: root.btnSpacing
                anchors {
                    right: parent.right
                    rightMargin: root.btnSideMargin
                    verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: options.titleButtonsRight
                    delegate: ShiftButton { btnType: modelData }
                }
            }

            Component.onCompleted: decoration.installTitleItem(titleRow)
        }
    }

    // ── Button component ─────────────────────────────────────────────────────
    component ShiftButton: DecorationButton {
        property int btnType: DecorationOptions.DecorationButtonNone
        readonly property bool isSpacer: btnType === DecorationOptions.DecorationButtonExplicitSpacer
        readonly property bool supported: {
            switch (btnType) {
            case DecorationOptions.DecorationButtonExplicitSpacer:
            case DecorationOptions.DecorationButtonClose:
            case DecorationOptions.DecorationButtonMinimize:
            case DecorationOptions.DecorationButtonMaximizeRestore:
            case DecorationOptions.DecorationButtonMenu:
            case DecorationOptions.DecorationButtonApplicationMenu:
                return true;
            default:
                return false;
            }
        }
        buttonType: btnType
        width: isSpacer ? root.btnSpacing * 2 : (supported ? root.btnSize : 0)
        height: isSpacer ? 1 : (supported ? root.btnSize : 0)
        visible: supported

        readonly property color normalColor: {
            switch (btnType) {
            case DecorationOptions.DecorationButtonClose:           return "#C4455D";
            case DecorationOptions.DecorationButtonMenu:
            case DecorationOptions.DecorationButtonApplicationMenu:
            case DecorationOptions.DecorationButtonMinimize:
            case DecorationOptions.DecorationButtonMaximizeRestore: return "#2b3246";
            default:                                                return "#2b3246";
            }
        }
        readonly property color hoverColor: {
            switch (btnType) {
            case DecorationOptions.DecorationButtonClose:           return "#E05D76";
            case DecorationOptions.DecorationButtonMinimize:
            case DecorationOptions.DecorationButtonMaximizeRestore:
            case DecorationOptions.DecorationButtonMenu:
            case DecorationOptions.DecorationButtonApplicationMenu: return "#3b435c";
            default:                                                return "#3b435c";
            }
        }
        readonly property color symbolColor: {
            switch (btnType) {
            case DecorationOptions.DecorationButtonClose:           return "#ffffff";
            case DecorationOptions.DecorationButtonMenu:
            case DecorationOptions.DecorationButtonApplicationMenu:
            case DecorationOptions.DecorationButtonMinimize:
            case DecorationOptions.DecorationButtonMaximizeRestore: return "#eaf2ff";
            default:                                                return "#eaf2ff";
            }
        }
        readonly property string symbol: {
            switch (btnType) {
            case DecorationOptions.DecorationButtonClose:           return "\u00d7";
            case DecorationOptions.DecorationButtonMinimize:        return "\u2212";
            case DecorationOptions.DecorationButtonMaximizeRestore:
                return decoration.client.maximized ? "\u25a3" : "\u25a1";
            case DecorationOptions.DecorationButtonMenu:
            case DecorationOptions.DecorationButtonApplicationMenu: return "\u2261";
            default: return "";
            }
        }

        // Snap-assist hover trigger lives in the shift-tiling KWin script:
        // the decoration QML sandbox has no DBus / kglobalaccel access, so
        // the script polls the cursor over the active window's titlebar
        // and invokes the SHIFT Snap Assist shortcut after a short hover.

        Rectangle {
            visible: !isSpacer
            anchors.fill: parent
            radius: width / 2
            antialiasing: true
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.18)
            color: parent.pressed  ? Qt.darker(parent.hoverColor, 1.3)
                 : parent.hovered  ? parent.hoverColor
                                   : parent.normalColor
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: parent.parent.symbol
                color: parent.parent.symbolColor
                font.pixelSize: Math.round(parent.width * 0.66)
                font.weight: Font.Bold
                opacity: 1.0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }
}
