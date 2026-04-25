// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components 3.0 as PC3
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings
import org.kde.plasma.private.mobileshell.screenbrightnessplugin as ScreenBrightness
import org.kde.plasma.private.volume
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.bluezqt 1.0 as BluezQt
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.quicksetting.nightcolor as NightColor

Item {
    id: root
    anchors.fill: parent

    property bool opened: false
    readonly property string acceptButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonA)
    readonly property string closeButtonLabel: GamingShell.GamepadManager.buttonLabel(GamingShell.GamepadManager.ButtonB)

    function pulsePrimaryGamepad(lowIntensity, highIntensity, durationMs) {
        var pad = GamingShell.GamepadManager.primaryGamepad
        if (!pad || !pad.hasRumble) {
            return
        }
        pad.rumble(lowIntensity, highIntensity, durationMs)
    }

    // Focusable controls for gamepad navigation
    property var _controls: []
    property int _focusIndex: 0

    function _buildControlsList() {
        var list = []
        if (GamingShell.PowerProfileControl.available && performanceSection._availableProfiles.length > 0) list.push(profileRow)
        if (screenBrightness.brightnessAvailable) list.push(brightnessSlider)
        if (PreferredDevice.sink) list.push(volumeSlider)
        list.push(dndSwitch)
        list.push(launchHintSwitch)
        list.push(nightColorSwitch)
        list.push(overlaySwitch)
        list.push(wifiSwitch)
        list.push(btSwitch)
        list.push(airplaneSwitch)
        _controls = list
    }

    function open() {
        opened = true
        _buildControlsList()
        _focusIndex = Math.max(0, Math.min(_focusIndex, _controls.length - 1))
        _highlightCurrent()
        pulsePrimaryGamepad(7000, 11000, 40)
    }
    function close() {
        opened = false
        pulsePrimaryGamepad(5000, 8000, 30)
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
        if (typeof ctrl.decrease === "function") {
            ctrl.decrease()
            if (typeof ctrl.moved === "function") ctrl.moved()
        }
    }
    function gamepadRight() {
        var ctrl = _controls[_focusIndex]
        if (typeof ctrl.increase === "function") {
            ctrl.increase()
            if (typeof ctrl.moved === "function") ctrl.moved()
        }
    }
    function gamepadAccept() {
        var ctrl = _controls[_focusIndex]
        if (ctrl === profileRow) {
            ctrl.increase()
            pulsePrimaryGamepad(6000, 9000, 35)
            return
        }
        if (ctrl instanceof QQC2.Switch) {
            ctrl.toggle()
            ctrl.toggled()
            pulsePrimaryGamepad(6000, 9000, 35)
        }
    }

    onOpenedChanged: {
        if (opened) {
            _buildControlsList()
            _focusIndex = Math.max(0, Math.min(_focusIndex, _controls.length - 1))
            _highlightCurrent()
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

                // ---- Performance Profile ----
                ColumnLayout {
                    id: performanceSection
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: GamingShell.PowerProfileControl.available
                             && _availableProfiles.length > 0

                    PC3.Label {
                        text: i18n("Performance")
                        font.bold: true
                    }

                    // Ordered low-to-high so gamepad left=slower, right=faster
                    readonly property var _profileOrder: ["power-saver", "balanced", "performance"]
                    readonly property var _availableProfiles: {
                        var ordered = []
                        for (var i = 0; i < _profileOrder.length; i++) {
                            if (GamingShell.PowerProfileControl.profiles.indexOf(_profileOrder[i]) >= 0) {
                                ordered.push(_profileOrder[i])
                            }
                        }
                        return ordered
                    }

                    Item {
                        id: profileRow
                        focus: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: profileButtons.implicitHeight

                        function decrease() {
                            var profiles = parent._availableProfiles
                            var idx = profiles.indexOf(GamingShell.PowerProfileControl.activeProfile)
                            if (idx > 0) {
                                GamingShell.PowerProfileControl.activeProfile = profiles[idx - 1]
                            }
                        }
                        function increase() {
                            var profiles = parent._availableProfiles
                            var idx = profiles.indexOf(GamingShell.PowerProfileControl.activeProfile)
                            if (idx >= 0 && idx < profiles.length - 1) {
                                GamingShell.PowerProfileControl.activeProfile = profiles[idx + 1]
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Kirigami.Units.smallSpacing
                            radius: Kirigami.Units.smallSpacing
                            color: "transparent"
                            border.color: Kirigami.Theme.highlightColor
                            border.width: parent.activeFocus ? 2 : 0
                        }

                        RowLayout {
                            id: profileButtons
                            anchors.left: parent.left
                            anchors.right: parent.right
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: performanceSection._availableProfiles

                                QQC2.Button {
                                    Layout.fillWidth: true
                                    text: {
                                        switch (modelData) {
                                        case "performance": return i18n("Performance")
                                        case "balanced": return i18n("Balanced")
                                        case "power-saver": return i18n("Power Saver")
                                        default: return modelData
                                        }
                                    }
                                    icon.name: {
                                        switch (modelData) {
                                        case "performance": return "speedometer"
                                        case "balanced": return "system-suspend-hibernate"
                                        case "power-saver": return "battery-profile-powersave"
                                        default: return ""
                                        }
                                    }
                                    highlighted: GamingShell.PowerProfileControl.activeProfile === modelData
                                    onClicked: GamingShell.PowerProfileControl.activeProfile = modelData
                                }
                            }
                        }
                    }
                }

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

                            // Keep Plasma/Kirigami colors while using a cleaner rounded style.
                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                width: brightnessSlider.availableWidth
                                height: Kirigami.Units.smallSpacing + 2
                                radius: height / 2
                                color: Kirigami.Theme.alternateBackgroundColor

                                Rectangle {
                                    width: parent.width * brightnessSlider.visualPosition
                                    height: parent.height
                                    radius: parent.radius
                                    color: Kirigami.Theme.highlightColor
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Kirigami.Theme.highlightColor
                                    border.width: brightnessSlider.activeFocus ? 1 : 0
                                }
                            }

                            handle: Rectangle {
                                x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                radius: width / 2
                                color: Kirigami.Theme.backgroundColor
                                border.color: brightnessSlider.pressed
                                              ? Kirigami.Theme.highlightColor
                                              : Kirigami.Theme.disabledTextColor
                                border.width: brightnessSlider.activeFocus || brightnessSlider.pressed ? 2 : 1
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

                            // Keep Plasma/Kirigami colors while using a cleaner rounded style.
                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: Kirigami.Units.smallSpacing + 2
                                radius: height / 2
                                color: Kirigami.Theme.alternateBackgroundColor

                                Rectangle {
                                    width: parent.width * volumeSlider.visualPosition
                                    height: parent.height
                                    radius: parent.radius
                                    color: Kirigami.Theme.highlightColor
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: Kirigami.Theme.highlightColor
                                    border.width: volumeSlider.activeFocus ? 1 : 0
                                }
                            }

                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                radius: width / 2
                                color: Kirigami.Theme.backgroundColor
                                border.color: volumeSlider.pressed
                                              ? Kirigami.Theme.highlightColor
                                              : Kirigami.Theme.disabledTextColor
                                border.width: volumeSlider.activeFocus || volumeSlider.pressed ? 2 : 1
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

                // ---- Gaming Tweaks ----
                PC3.Label {
                    text: i18n("Gaming")
                    font.bold: true
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.largeSpacing

                    QQC2.Switch {
                        id: dndSwitch
                        text: i18n("Do Not Disturb")
                        checked: MobileShellState.ShellDBusClient.doNotDisturb
                        onToggled: MobileShellState.ShellDBusClient.doNotDisturb = checked
                    }

                    QQC2.Switch {
                        id: launchHintSwitch
                        text: i18n("Launch Hint")
                        checked: ShellSettings.Settings.gamingDismissHintEnabled
                        onToggled: ShellSettings.Settings.gamingDismissHintEnabled = checked
                    }

                    QQC2.Switch {
                        id: nightColorSwitch
                        text: i18n("Night Color")
                        checked: NightColor.NightColorUtil.enabled
                        onToggled: NightColor.NightColorUtil.enabled = checked
                    }

                    QQC2.Switch {
                        id: overlaySwitch
                        text: i18n("Perf Overlay")
                        checked: GamingShell.GameLauncherProvider.overlayEnabled
                        enabled: GamingShell.GameLauncherProvider.mangohudAvailable
                        opacity: enabled ? 1.0 : 0.5
                        onToggled: GamingShell.GameLauncherProvider.overlayEnabled = checked

                        QQC2.ToolTip.visible: !GamingShell.GameLauncherProvider.mangohudAvailable && hovered
                        QQC2.ToolTip.text: i18n("MangoHud is not installed")
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }

                    // FPS cap — spans both columns, driven by MangoHud fps_limit
                    QQC2.ButtonGroup { id: fpsCap; exclusive: true }

                    RowLayout {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        enabled: GamingShell.GameLauncherProvider.mangohudAvailable
                        opacity: enabled ? 1.0 : 0.5

                        PC3.Label { text: i18n("FPS Cap") }
                        Item { Layout.fillWidth: true }

                        Repeater {
                            model: [
                                { label: i18nc("@action:button FPS cap off", "Off"), fps: 0 },
                                { label: "30", fps: 30 },
                                { label: "40", fps: 40 },
                                { label: "60", fps: 60 }
                            ]
                            delegate: QQC2.Button {
                                required property var modelData
                                text: modelData.label
                                flat: true
                                checkable: true
                                checked: GamingShell.GameLauncherProvider.fpsLimit === modelData.fps
                                QQC2.ButtonGroup.group: fpsCap
                                onClicked: GamingShell.GameLauncherProvider.fpsLimit = modelData.fps
                            }
                        }
                    }

                    // GameMode status (auto-managed, read-only indicator)
                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        visible: GamingShell.GameModeControl.available

                        Kirigami.Icon {
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: Kirigami.Units.iconSizes.small
                            source: "games-achievements"
                        }
                        PC3.Label {
                            text: GamingShell.GameModeControl.active
                                  ? i18n("GameMode requested")
                                  : i18n("GameMode not requested")
                            opacity: 0.7
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
                    text: i18n("↕: Navigate  ↔: Adjust  %1: Toggle  %2: Close",
                               acceptButtonLabel, closeButtonLabel)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.8
                    opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
