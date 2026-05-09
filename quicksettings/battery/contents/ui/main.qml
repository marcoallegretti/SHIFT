// SPDX-FileCopyrightText: 2022 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick 2.15

import org.kde.plasma.private.mobileshell.quicksettingsplugin as QS
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.private.mobileshell.gamingshellplugin as GamingShell

QS.QuickSetting {
    id: root

    readonly property var profileOrder: ["power-saver", "balanced", "performance"]
    readonly property bool profileAvailable: GamingShell.PowerProfileControl.available
                                         && GamingShell.PowerProfileControl.profiles.length > 0
    property var toggle: profileAvailable ? root.cycleProfile : undefined

    text: i18n("Battery")
    status: profileAvailable
        ? i18n("%1% - %2", MobileShell.BatteryInfo.percent, profileLabel(GamingShell.PowerProfileControl.activeProfile))
        : i18n("%1%", MobileShell.BatteryInfo.percent)
    icon: profileAvailable ? profileIcon(GamingShell.PowerProfileControl.activeProfile)
                           : "battery-full" + (MobileShell.BatteryInfo.pluggedIn ? "-charging" : "")
    enabled: profileAvailable && GamingShell.PowerProfileControl.activeProfile !== "balanced"
    settingsCommand: "plasma-open-settings kcm_mobile_power"

    function profileLabel(profile) {
        switch (profile) {
        case "performance": return i18n("Performance")
        case "balanced": return i18n("Balanced")
        case "power-saver": return i18n("Power Saver")
        default: return profile
        }
    }

    function profileIcon(profile) {
        switch (profile) {
        case "performance": return "speedometer"
        case "power-saver": return "battery-profile-powersave"
        default: return "battery-full" + (MobileShell.BatteryInfo.pluggedIn ? "-charging" : "")
        }
    }

    function cycleProfile() {
        let availableProfiles = []
        for (let i = 0; i < profileOrder.length; ++i) {
            let profile = profileOrder[i]
            if (GamingShell.PowerProfileControl.profiles.indexOf(profile) >= 0) {
                availableProfiles.push(profile)
            }
        }

        if (availableProfiles.length === 0) {
            return
        }

        let currentIndex = availableProfiles.indexOf(GamingShell.PowerProfileControl.activeProfile)
        let nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1) % availableProfiles.length
        GamingShell.PowerProfileControl.activeProfile = availableProfiles[nextIndex]
    }
}
