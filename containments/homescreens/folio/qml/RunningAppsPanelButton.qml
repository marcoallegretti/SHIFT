// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3

MouseArea {
    id: button

    property string iconName
    property string toolTipText
    property bool checked: false

    signal triggered()

    function _mix(base, overlay, ratio) {
        return Qt.rgba(
            base.r + (overlay.r - base.r) * ratio,
            base.g + (overlay.g - base.g) * ratio,
            base.b + (overlay.b - base.b) * ratio,
            base.a + (overlay.a - base.a) * ratio)
    }

    width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2
    height: width
    hoverEnabled: enabled
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.35

    onClicked: button.triggered()

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.cornerRadius
        color: button.containsPress
            ? button._mix(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.16)
            : button.checked
                ? button._mix(Kirigami.Theme.backgroundColor, Kirigami.Theme.highlightColor, button.containsMouse ? 0.22 : 0.16)
                : button.containsMouse
                    ? button._mix(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.08)
                    : "transparent"

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: Kirigami.Units.iconSizes.small
        height: width
        source: button.iconName
        active: button.containsMouse || button.checked
    }

    PC3.ToolTip {
        text: button.toolTipText
        visible: button.containsMouse && button.toolTipText.length > 0
    }
}
