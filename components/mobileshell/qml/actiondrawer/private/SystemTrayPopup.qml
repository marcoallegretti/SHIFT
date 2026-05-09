// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.1

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.systemtray as SystemTray

QQC2.Popup {
    id: popup

    modal: true
    dim: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside

    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    width: Math.min(Kirigami.Units.gridUnit * 22,
                    parent ? parent.width - Kirigami.Units.gridUnit * 4 : 420)
    height: Math.min(Kirigami.Units.gridUnit * 24,
                     parent ? parent.height - Kirigami.Units.gridUnit * 4 : 480)

    padding: Kirigami.Units.smallSpacing

    readonly property int trayItemCount: trayList.count

    function show() {
        popup.open();
    }

    SystemTray.StatusNotifierModel {
        id: trayModel
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

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                source: "preferences-desktop-notification-symbolic"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    text: i18n("System Tray")
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: trayList.count > 0 ? i18np("%1 status item", "%1 status items", trayList.count) : i18n("No status items")
                    opacity: 0.65
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Kirigami.ColorUtils.linearInterpolation(
                Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.12)
        }

        ListView {
            id: trayList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Kirigami.Units.smallSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: trayModel

            delegate: Item {
                id: trayItem

                width: ListView.view.width
                height: Kirigami.Units.gridUnit * 3

                readonly property string itemTitle: model.toolTipTitle ? model.toolTipTitle : (model.title ? model.title : i18n("Status Item"))
                readonly property string itemStatus: {
                    if (model.status === "Passive") {
                        return i18n("Hidden");
                    }
                    if (model.category === "ApplicationStatus") {
                        return i18n("Application status");
                    }
                    return model.status ? model.status : i18n("Active");
                }
                readonly property bool itemActive: model.category !== "ApplicationStatus" && model.status !== "Passive"

                function triggerOperation(operationName) {
                    if (!model.service) {
                        return;
                    }

                    let operation = model.service.operationDescription(operationName);
                    if (!operation) {
                        return;
                    }

                    let operationPoint = trayItem.mapToGlobal(trayItem.width, trayItem.height / 2);
                    operation.x = operationPoint.x;
                    operation.y = operationPoint.y;
                    model.service.startOperationCall(operation);
                }

                Rectangle {
                    id: rowBackground
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing
                    anchors.rightMargin: Kirigami.Units.smallSpacing
                    radius: Kirigami.Units.cornerRadius
                    color: trayMouse.pressed ? Qt.rgba(Kirigami.Theme.textColor.r,
                                                       Kirigami.Theme.textColor.g,
                                                       Kirigami.Theme.textColor.b, 0.08)
                         : trayMouse.containsMouse ? Qt.rgba(Kirigami.Theme.textColor.r,
                                                             Kirigami.Theme.textColor.g,
                                                             Kirigami.Theme.textColor.b, 0.04)
                         : Kirigami.Theme.alternateBackgroundColor
                    border.width: 1
                    border.color: Kirigami.ColorUtils.linearInterpolation(
                        Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, trayItem.itemActive ? 0.16 : 0.08)
                    opacity: trayItem.itemActive ? 1 : 0.72
                }

                RowLayout {
                    anchors.fill: rowBackground
                    anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                    anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        source: model.iconName ? model.iconName : (model.icon ? model.icon : "")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        MobileShell.MarqueeLabel {
                            Layout.fillWidth: true
                            inputText: trayItem.itemTitle
                            font.weight: Font.Bold
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                        }

                        MobileShell.MarqueeLabel {
                            Layout.fillWidth: true
                            inputText: trayItem.itemStatus
                            opacity: 0.6
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                        }
                    }

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        source: "go-next-symbolic"
                        opacity: 0.45
                    }
                }

                QQC2.ToolTip.text: trayItem.itemTitle
                QQC2.ToolTip.visible: trayMouse.containsMouse && trayItem.itemTitle !== ""
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                MouseArea {
                    id: trayMouse
                    anchors.fill: rowBackground
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: (mouse) => {
                        trayItem.triggerOperation(mouse.button === Qt.RightButton ? "ContextMenu" : "Activate");
                    }
                }
            }

            QQC2.Label {
                anchors.centerIn: parent
                visible: trayList.count === 0
                text: i18n("No status items")
                opacity: 0.65
            }
        }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Kirigami.Units.shortDuration; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Kirigami.Units.shortDuration; easing.type: Easing.InCubic }
    }

    QQC2.Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
    }
}