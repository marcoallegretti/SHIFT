// SPDX-FileCopyrightText: 2021-2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.plasma.components 3.0 as PlasmaComponents
import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio
import './delegate'

Item {
    id: root
    property Folio.HomeScreen folio

    // Do not override the colorset: in mobile mode we inherit Complementary
    // from the containment (wallpaper context, white text); in convergence mode
    // the drawerOverlay Window gives us Window context (system-adaptive).

    function addSearchText(text: string) {
        searchField.text += text;
    }

    function clearSearchText(): void {
        searchField.text = '';
    }

    // Request to not focus on the search bar
    signal releaseFocusRequested()

    onFocusChanged: {
        if (focus) {
            searchField.focus = true;
        }
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            root.releaseFocusRequested();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.topMargin: Kirigami.Units.largeSpacing
        anchors.leftMargin: Kirigami.Units.gridUnit + Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.gridUnit + Kirigami.Units.largeSpacing
        anchors.fill: parent

        Kirigami.SearchField {
            id: searchField
            onTextChanged: folio.ApplicationListSearchModel.setFilterFixedString(text)
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            Layout.alignment: Qt.AlignHCenter

            background: Rectangle {
                radius: Kirigami.Units.cornerRadius
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b,
                               (searchField.hovered || searchField.focus) ? 0.2 : 0.1)

                Behavior on color { ColorAnimation {} }
            }

            topPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            horizontalAlignment: QQC2.TextField.AlignHCenter
            placeholderText: i18nc("@info:placeholder", "Search applications…")
            placeholderTextColor: Kirigami.Theme.disabledTextColor
            color: Kirigami.Theme.textColor

            font.weight: Font.Bold

            Connections {
                target: folio.HomeScreenState
                function onViewStateChanged(): void {
                    if (folio.HomeScreenState.viewState !== Folio.HomeScreenState.AppDrawerView) {
                        // Reset search field if the app drawer is not shown
                        if (searchField.text !== '') {
                            searchField.text = '';
                        }
                    }
                }
            }
        }


    }
}
