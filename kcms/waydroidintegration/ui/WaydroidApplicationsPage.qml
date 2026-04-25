/*
 * SPDX-FileCopyrightText: 2025 Florian RICHER <florian.richer@protonmail.com>
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kirigamiaddons.formcard 1.0 as FormCard
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell.waydroidintegrationplugin as AIP

KCM.SimpleKCM {
    id: root

    function packagePatterns(value: string): var {
        if (value === "") {
            return []
        }

        return value.split(",")
            .map(pattern => pattern.trim())
            .filter(pattern => pattern !== "")
    }

    function wildcardRegExp(pattern: string): RegExp {
        const escaped = pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&")
        return new RegExp("^" + escaped.replace(/\*/g, ".*") + "$")
    }

    function hasExactPackage(value: string, packageName: string): bool {
        return packagePatterns(value).includes(packageName)
    }

    function hasWildcardPackage(value: string, packageName: string): bool {
        return packagePatterns(value)
            .filter(pattern => pattern.includes("*"))
            .some(pattern => wildcardRegExp(pattern).test(packageName))
    }

    function hasEffectivePackage(value: string, packageName: string): bool {
        return hasExactPackage(value, packageName) || hasWildcardPackage(value, packageName)
    }

    function updateExactPackage(value: string, packageName: string, enabled: bool): string {
        const updatedPatterns = packagePatterns(value).filter(pattern => pattern !== packageName)

        if (enabled) {
            updatedPatterns.push(packageName)
        }

        return updatedPatterns.join(",")
    }

    topPadding: Kirigami.Units.largeSpacing
    bottomPadding: Kirigami.Units.largeSpacing
    leftPadding: 0
    rightPadding: 0

    title: i18n("Waydroid applications")

    actions: [
        Kirigami.Action {
            text: i18nc("@action:button", "Install APK")
            icon.name: "list-add"

            onTriggered: fileDialog.open()
        }
    ]

    Connections {
        target: AIP.WaydroidDBusClient

        function onActionFinished(message: string): void {
            inlineMessage.text = message
            inlineMessage.visible = true
            inlineMessage.type = Kirigami.MessageType.Positive
        }

        function onActionFailed(error: string): void {
            inlineMessage.text = error
            inlineMessage.visible = true
            inlineMessage.type = Kirigami.MessageType.Error
        }
    }

    Timer {
        id: autoRefreshApplicationsTimer
        interval: 2000
        repeat: true
        running: root.visible
        onTriggered: AIP.WaydroidDBusClient.refreshApplications()
    }

    FileDialog {
        id: fileDialog
        nameFilters: [ "APK files (*.apk)" ]

        onAccepted: {
            const url = new URL(selectedFile)
            if (url.protocol !== "file:") {
                inlineMessage.text = i18n("You must select a local file")
                inlineMessage.visible = true
                inlineMessage.type = Kirigami.MessageType.Error
            } else {
                AIP.WaydroidDBusClient.installApk(url.pathname)
            }
        }
    }

    ColumnLayout {
        visible: AIP.WaydroidDBusClient.status === AIP.WaydroidDBusClient.Initialized
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            id: inlineMessage

            Layout.fillWidth: true

            visible: false
            showCloseButton: true
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            explanation: i18n("This page manages the launchers exported by Waydroid. Enable Show in Game Shell for Android apps you want listed in Game Center's Waydroid tab. Touch and Wi-Fi toggles add or remove exact package names from Waydroid's documented compatibility property lists. Wildcard rules remain in the main Waydroid properties page.")
        }

        FormCard.FormCard {
            Repeater {
                model: AIP.WaydroidDBusClient.applicationListModel

                delegate: FormCard.AbstractFormDelegate {
                    id: appDelegate

                    width: ListView.view.width

                    background: null
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: model.name
                                elide: Text.ElideRight
                            }

                            QQC2.ToolButton {
                                display: QQC2.AbstractButton.IconOnly
                                text: i18nc("@action:button", "Launch the application")
                                icon.name: "media-playback-start"

                                onClicked: AIP.WaydroidDBusClient.launchApplication(model.id)

                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }

                            QQC2.ToolButton {
                                display: QQC2.AbstractButton.IconOnly
                                text: i18nc("@action:button", "Delete the application")
                                icon.name: "usermenu-delete"

                                onClicked: AIP.WaydroidDBusClient.deleteApplication(model.id)

                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: text
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.CheckBox {
                                text: i18n("Show in Game Shell")
                                checked: AIP.WaydroidDBusClient.gameShellPackages.indexOf(model.id) !== -1

                                onClicked: AIP.WaydroidDBusClient.setGameShellEnabledForPackage(model.id, checked)
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Kirigami.Theme.disabledTextColor
                            text: i18n("Adds this app to the Game Shell allowlist so it appears in Game Center under Waydroid.")
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            QQC2.CheckBox {
                                id: fakeTouchToggle
                                text: i18n("Touch")
                                checked: root.hasEffectivePackage(AIP.WaydroidDBusClient.fakeTouch, model.id)
                                enabled: !root.hasWildcardPackage(AIP.WaydroidDBusClient.fakeTouch, model.id)

                                onClicked: {
                                    AIP.WaydroidDBusClient.fakeTouch = root.updateExactPackage(AIP.WaydroidDBusClient.fakeTouch, model.id, checked)
                                }

                                QQC2.ToolTip.visible: hovered && !enabled
                                QQC2.ToolTip.text: i18n("Managed by a wildcard pattern in Waydroid properties")
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }

                            QQC2.CheckBox {
                                id: fakeWifiToggle
                                text: i18n("Wi-Fi")
                                checked: root.hasEffectivePackage(AIP.WaydroidDBusClient.fakeWifi, model.id)
                                enabled: !root.hasWildcardPackage(AIP.WaydroidDBusClient.fakeWifi, model.id)

                                onClicked: {
                                    AIP.WaydroidDBusClient.fakeWifi = root.updateExactPackage(AIP.WaydroidDBusClient.fakeWifi, model.id, checked)
                                }

                                QQC2.ToolTip.visible: hovered && !enabled
                                QQC2.ToolTip.text: i18n("Managed by a wildcard pattern in Waydroid properties")
                                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                            }
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: !fakeTouchToggle.enabled || !fakeWifiToggle.enabled
                            wrapMode: Text.WordWrap
                            color: Kirigami.Theme.disabledTextColor
                            text: i18n("One or more compatibility settings for this app come from a wildcard rule. Edit the global Waydroid property to change that rule.")
                        }
                    }
                }

                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
            }
        }
    }

    ColumnLayout {
        visible: AIP.WaydroidDBusClient.status !== AIP.WaydroidDBusClient.Initialized
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            text: i18n("Waydroid is unavailable")
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
        }

        PC3.Button {
            text: i18n("Check again")
            Layout.alignment: Qt.AlignHCenter
            onClicked: AIP.WaydroidDBusClient.refreshSupportsInfo()
        }
    }
}
