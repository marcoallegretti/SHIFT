// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell
import org.kde.plasma.private.mobileshell.screenbrightnessplugin as ScreenBrightness
import org.kde.plasma.private.volume
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt 1.0 as BluezQt

Item {
    id: root
    anchors.fill: parent

    property bool opened: false

    // Focusable controls for gamepad navigation
    property var _controls: []
    property int _focusIndex: 0

    function _buildControlsList() {
        var list = []
        if (screenBrightness.brightnessAvailable) list.push(brightnessSlider)
        if (PreferredDevice.sink) list.push(volumeSlider)
        list.push(wifiSwitch)
        list.push(btSwitch)
        list.push(airplaneSwitch)
        _controls = list
    }

    function open() {
        opened = true
        _buildControlsList()
        _focusIndex = 0
        _highlightCurrent()
    }
    function close() {
        opened = false
    }
    function toggle() {
        if (opened) close(); else open()
    }

    function _highlightCurrent() {
        if (_controls.length > 0 && _focusIndex >= 0 && _focusIndex < _controls.length) {
            _controls[_focusIndex].forceActiveFocus()
        }
    }

    // Gamepad input handlers called from GameCenterOverlay
    function gamepadUp() {
        if (_focusIndex > 0) {
            _focusIndex--
            _highlightCurrent()
        }
    }
    function gamepadDown() {
        if (_focusIndex < _controls.length - 1) {
            _focusIndex++
            _highlightCurrent()
        }
    }
    function gamepadLeft() {
        var ctrl = _controls[_focusIndex]
        if (ctrl instanceof PC3.Slider) {
            ctrl.decrease()
            ctrl.moved()
        }
    }
    function gamepadRight() {
        var ctrl = _controls[_focusIndex]
        if (ctrl instanceof PC3.Slider) {
            ctrl.increase()
            ctrl.moved()
        }
    }
    function gamepadAccept() {
        var ctrl = _controls[_focusIndex]
        if (ctrl instanceof QQC2.Switch) {
            ctrl.toggle()
            ctrl.toggled()
        }
    }

    // Eat clicks on the dimmed backdrop
    MouseArea {
        anchors.fill: parent
        visible: root.opened
        onClicked: root.close()
    }

    // Dim backdrop
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.opened ? 0.4 : 0
        Behavior on opacity {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }
    }

    // Panel sliding in from the right
    Rectangle {
        id: panel
        width: Math.min(root.width * 0.35, Kirigami.Units.gridUnit * 22)
        height: root.height
        anchors.top: root.top
        anchors.bottom: root.bottom

        x: root.opened ? root.width - width : root.width

        Behavior on x {
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
        }

        Kirigami.Theme.inherit: false
        Kirigami.Theme.colorSet: Kirigami.Theme.Window
        color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                       Kirigami.Theme.backgroundColor.g,
                       Kirigami.Theme.backgroundColor.b, 0.96)

        // Subtle left border
        Rectangle {
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.3
        }

        ScreenBrightness.ScreenBrightnessUtil {
            id: screenBrightness
        }

        PlasmaNM.Handler {
            id: nmHandler
        }

        PlasmaNM.EnabledConnections {
            id: enabledConnections
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing * 2
            contentHeight: settingsColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: settingsColumn
                width: parent.width
                spacing: Kirigami.Units.largeSpacing * 2

                // ---- Header ----
                RowLayout {
                    Layout.fillWidth: true

                    Kirigami.Heading {
                        text: i18n("Quick Settings")
                        level: 2
                        Layout.fillWidth: true
                    }

                    QQC2.ToolButton {
                        icon.name: "window-close-symbolic"
                        onClicked: root.close()
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ---- Brightness ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: screenBrightness.brightnessAvailable

                    PC3.Label {
                        text: i18n("Brightness")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            source: "low-brightness"
                        }

                        PC3.Slider {
                            id: brightnessSlider
                            Layout.fillWidth: true
                            from: 1
                            to: screenBrightness.maxBrightness
                            stepSize: Math.max(1, Math.round(screenBrightness.maxBrightness / 20))
                            value: screenBrightness.brightness
                            onMoved: screenBrightness.brightness = value

                            Timer {
                                interval: 0
                                running: true
                                repeat: false
                                onTriggered: brightnessSlider.value = Qt.binding(() => screenBrightness.brightness)
                            }

                            // Focus highlight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Kirigami.Units.smallSpacing
                                radius: Kirigami.Units.smallSpacing
                                color: "transparent"
                                border.color: Kirigami.Theme.highlightColor
                                border.width: parent.activeFocus ? 2 : 0
                            }
                        }

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            source: "high-brightness"
                        }
                    }
                }

                // ---- Volume ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: PreferredDevice.sink != null

                    PC3.Label {
                        text: i18n("Volume")
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            source: "audio-volume-low"
                        }

                        PC3.Slider {
                            id: volumeSlider
                            Layout.fillWidth: true
                            from: PulseAudio.MinimalVolume
                            to: PulseAudio.NormalVolume
                            stepSize: PulseAudio.NormalVolume / 20
                            value: PreferredDevice.sink ? PreferredDevice.sink.volume : 0
                            onMoved: {
                                if (PreferredDevice.sink) {
                                    PreferredDevice.sink.volume = value
                                    PreferredDevice.sink.muted = (value === 0)
                                }
                            }

                            // Focus highlight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Kirigami.Units.smallSpacing
                                radius: Kirigami.Units.smallSpacing
                                color: "transparent"
                                border.color: Kirigami.Theme.highlightColor
                                border.width: parent.activeFocus ? 2 : 0
                            }
                        }

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            source: "audio-volume-high"
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ---- Connectivity toggles ----
                PC3.Label {
                    text: i18n("Connectivity")
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.largeSpacing

                    // WiFi toggle
                    QQC2.Switch {
                        id: wifiSwitch
                        text: i18n("Wi-Fi")
                        checked: enabledConnections.wirelessEnabled
                        onToggled: nmHandler.enableWireless(checked)
                    }

                    // Bluetooth toggle
                    QQC2.Switch {
                        id: btSwitch
                        text: i18n("Bluetooth")
                        checked: !BluezQt.Manager.bluetoothBlocked
                        onToggled: BluezQt.Manager.bluetoothBlocked = !checked
                    }

                    // Airplane mode
                    QQC2.Switch {
                        id: airplaneSwitch
                        text: i18n("Airplane Mode")
                        checked: PlasmaNM.Configuration.airplaneModeEnabled
                        onToggled: {
                            nmHandler.enableAirplaneMode(!PlasmaNM.Configuration.airplaneModeEnabled)
                            PlasmaNM.Configuration.airplaneModeEnabled = !PlasmaNM.Configuration.airplaneModeEnabled
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ---- Battery info ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: MobileShell.BatteryInfo.isVisible

                    PC3.Label {
                        text: i18n("Battery")
                        font.bold: true
                    }

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        MobileShell.BatteryIndicator {
                            textPixelSize: Kirigami.Units.gridUnit * 0.7
                        }

                        PC3.Label {
                            text: MobileShell.BatteryInfo.pluggedIn ? i18n("Charging") : ""
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.85
                            opacity: 0.7
                        }
                    }
                }

                // ---- Controller info ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: GamingShell.GamepadManager.hasGamepad

                    PC3.Label {
                        text: i18n("Controllers")
                        font.bold: true
                    }

                    Repeater {
                        model: GamingShell.GamepadManager

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            required property string name
                            required property int battery
                            required property string type

                            Kirigami.Icon {
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                source: "input-gaming"
                            }

                            PC3.Label {
                                text: name
                            }

                            PC3.Label {
                                text: battery >= 0 ? battery + "%" : i18n("Wired")
                                opacity: 0.7
                            }
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // ---- Gamepad legend ----
                PC3.Label {
                    Layout.fillWidth: true
                    text: i18n("↕: Navigate  ↔: Adjust  A: Toggle  B: Close")
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                    opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
