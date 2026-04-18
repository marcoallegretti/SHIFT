/*
 *   SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Item {
    id: taskIcon
    width: parent.height
    height: width

    // Hide ApplicationStatus and Passive items
    opacity: (model.category !== "ApplicationStatus" && model.status !== "Passive") ? 1 : 0
    onOpacityChanged: visible = opacity

    Behavior on opacity {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    Kirigami.Icon {
        id: icon
        source: model.iconName ? model.iconName : (model.icon ? model.icon : "")
        width: Math.min(parent.width, parent.height)
        height: width
        anchors.centerIn: parent
    }

    Controls.ToolTip.text: model.toolTipTitle ? model.toolTipTitle : (model.title ? model.title : "")
    Controls.ToolTip.visible: mouseArea.containsMouse && Controls.ToolTip.text !== ""
    Controls.ToolTip.delay: Kirigami.Units.toolTipDelay

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (!model.service) {
                return;
            }

            var operationName = mouse.button === Qt.RightButton ? "ContextMenu" : "Activate";
            var operation = model.service.operationDescription(operationName);
            if (!operation) {
                return;
            }
            operation.x = taskIcon.mapToGlobal(0, 0).x;
            operation.y = taskIcon.mapToGlobal(0, taskIcon.height).y;
            model.service.startOperationCall(operation);
        }
    }
}
