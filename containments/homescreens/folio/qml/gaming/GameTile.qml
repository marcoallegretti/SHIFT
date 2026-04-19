// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.plasmoid

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio
import org.kde.plasma.components 3.0 as PC3

QQC2.ItemDelegate {
    id: root

    required property var folio
    required property Folio.FolioApplication application
    required property bool isCurrent

    signal launchRequested()

    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()

    onClicked: {
        if (!application) return
        if (application.icon !== "" && !application.running) {
            MobileShellState.ShellDBusClient.openAppLaunchAnimationWithPosition(
                Plasmoid.screen,
                application.icon,
                application.name,
                application.storageId,
                iconItem.Kirigami.ScenePosition.x + iconItem.width / 2,
                iconItem.Kirigami.ScenePosition.y + iconItem.height / 2,
                Math.min(iconItem.width, iconItem.height))
        }
        MobileShell.AppLaunch.launchOrActivateApp(application.storageId)
        launchRequested()
    }

    function launch() {
        clicked()
    }

    background: Rectangle {
        Kirigami.Theme.colorSet: Kirigami.Theme.Button
        color: root.isCurrent
               ? Kirigami.Theme.highlightColor
               : (root.hovered ? Kirigami.Theme.hoverColor : "transparent")
        radius: Kirigami.Units.cornerRadius

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            id: iconItem
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            source: root.application ? root.application.icon : ""

            scale: root.isCurrent ? 1.08 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.InOutQuad }
            }
        }

        PC3.Label {
            id: nameLabel
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.application ? root.application.name : ""
            maximumLineCount: 2
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.isCurrent ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

            Behavior on color {
                ColorAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }
}
