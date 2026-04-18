// SPDX-FileCopyrightText: Marco Allegretti
// SPDX-License-Identifier: EUPL 1.2

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio

Rectangle {
    id: root

    required property Folio.HomeScreen folio

    // Emitted when the user taps a tile.
    signal categorySelected(string categoryId)

    color: Kirigami.Theme.backgroundColor
    radius: Kirigami.Units.cornerRadius

    // Swallow clicks so the dismiss area underneath is not triggered.
    MouseArea { anchors.fill: parent }

    // ---------- helpers ----------

    function catDisplayName(cat) {
        switch (cat) {
        case "AudioVideo":  return i18n("Multimedia")
        case "Development": return i18n("Development")
        case "Education":   return i18n("Education")
        case "Game":        return i18n("Games")
        case "Graphics":    return i18n("Graphics")
        case "Network":     return i18n("Internet")
        case "Office":      return i18n("Office")
        case "Science":     return i18n("Science")
        case "System":      return i18n("System")
        case "Utility":     return i18n("Utilities")
        default:            return cat
        }
    }

    function catIconName(cat) {
        switch (cat) {
        case "AudioVideo":  return "applications-multimedia"
        case "Development": return "applications-development"
        case "Education":   return "applications-education"
        case "Game":        return "applications-games"
        case "Graphics":    return "applications-graphics"
        case "Network":     return "applications-internet"
        case "Office":      return "applications-office"
        case "Science":     return "applications-science"
        case "System":      return "applications-system"
        case "Utility":     return "applications-utilities"
        default:            return "applications-other"
        }
    }

    // ---------- model ----------

    ListModel { id: categoryModel }

    function populate() {
        categoryModel.clear()
        categoryModel.append({ catId: "",              catName: i18n("All Apps"),  catIcon: "applications-all" })
        const cats = folio.ApplicationListModel.allCategories()
        for (let i = 0; i < cats.length; i++) {
            categoryModel.append({
                catId:   cats[i],
                catName: root.catDisplayName(cats[i]),
                catIcon: root.catIconName(cats[i]),
            })
        }
    }

    Component.onCompleted: populate()

    Connections {
        target: folio.ApplicationListModel
        function onRowsInserted() { root.populate() }
        function onRowsRemoved()  { root.populate() }
        function onModelReset()   { root.populate() }
    }

    // ---------- tile list ----------

    QQC2.ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        contentWidth: availableWidth
        clip: true

        QQC2.ScrollBar.vertical.policy:   QQC2.ScrollBar.AsNeeded
        QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

        Column {
            width: scrollView.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: categoryModel

                delegate: Rectangle {
                    id: tile

                    required property string catId
                    required property string catName
                    required property string catIcon

                    readonly property bool isActive:
                        folio.ApplicationListSearchModel.categoryFilter === catId

                    width: parent.width
                    height: Kirigami.Units.iconSizes.medium + 2 * Kirigami.Units.largeSpacing
                    radius: Kirigami.Units.cornerRadius

                    color: isActive
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                                  Kirigami.Theme.highlightColor.g,
                                  Kirigami.Theme.highlightColor.b, 0.2)
                        : tileArea.containsPress
                            ? Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.2)
                            : tileArea.containsMouse
                                ? Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.1)
                                : "transparent"

                    // Active accent bar on left edge
                    Rectangle {
                        visible: tile.isActive
                        anchors.left:   parent.left
                        anchors.top:    parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin:    Kirigami.Units.smallSpacing
                        anchors.bottomMargin: Kirigami.Units.smallSpacing
                        width: 3
                        radius: 2
                        color: Kirigami.Theme.highlightColor
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin:  Kirigami.Units.largeSpacing
                            rightMargin: Kirigami.Units.smallSpacing
                        }
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width:  Kirigami.Units.iconSizes.medium
                            height: width
                            source: tile.catIcon
                            active: tileArea.containsMouse || tile.isActive
                        }

                        PlasmaComponents.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                                   - Kirigami.Units.iconSizes.medium
                                   - Kirigami.Units.largeSpacing * 2
                                   - Kirigami.Units.smallSpacing
                            text: tile.catName
                            elide: Text.ElideRight
                            font.weight: tile.isActive ? Font.Medium : Font.Normal
                            color: tile.isActive
                                ? Kirigami.Theme.highlightColor
                                : Kirigami.Theme.textColor
                        }
                    }

                    MouseArea {
                        id: tileArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: true
                        onClicked: root.categorySelected(tile.catId)

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                                root.categorySelected(tile.catId);
                                event.accepted = true;
                            }
                        }

                        Accessible.role: Accessible.Button
                        Accessible.name: tile.catName

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Kirigami.Theme.highlightColor
                            border.width: tileArea.activeFocus ? 2 : 0
                            radius: parent.parent.radius
                        }
                    }
                }
            }
        }
    }
}
