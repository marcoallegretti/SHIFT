// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell

/**
 * Popup hosting a Plasma applet's fullRepresentation for convergence mode.
 */
QQC2.Popup {
    id: popup

    modal: true
    dim: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    width: Math.min(Kirigami.Units.gridUnit * 18,
                    parent ? parent.width - Kirigami.Units.gridUnit * 4 : 360)
    height: Math.min(Kirigami.Units.gridUnit * 22,
                     parent ? parent.height - Kirigami.Units.gridUnit * 4 : 440)

    padding: Kirigami.Units.smallSpacing

    property string currentPluginId: ""
    property Item __currentItem: null

    function show(pluginId) {
        if (!pluginId) return;

        if (__currentItem && pluginId !== currentPluginId) {
            __currentItem.parent = null;
            __currentItem.visible = false;
            __currentItem = null;
        }

        currentPluginId = pluginId;

        var item = MobileShell.AppletHost.fullRepresentationFor(pluginId);
        if (!item) {
            console.warn("DetailPopup: no fullRepresentation for", pluginId);
            return;
        }

        __currentItem = item;
        item.parent = content;
        item.anchors.fill = content;
        item.visible = true;

        popup.open();
    }

    onClosed: {
        if (__currentItem) {
            __currentItem.visible = false;
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration; easing.type: Easing.InCubic }
    }

    background: Kirigami.ShadowedRectangle {
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.cornerRadius

        border.color: Kirigami.ColorUtils.linearInterpolation(
            Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.2)
        border.width: 1

        shadow.size: Kirigami.Units.gridUnit
        shadow.color: Qt.rgba(0, 0, 0, 0.45)
        shadow.yOffset: 2
    }

    contentItem: Item {
        id: content
    }

    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }
}
