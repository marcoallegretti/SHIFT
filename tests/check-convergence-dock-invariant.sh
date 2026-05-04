#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Marco Allegretti <mightymarco4@gmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

constants="$repo_root/components/mobileshell/qml/components/Constants.qml"
taskpanel="$repo_root/containments/taskpanel/qml/main.qml"
folio_main="$repo_root/containments/homescreens/folio/qml/main.qml"
folio_home="$repo_root/containments/homescreens/folio/qml/FolioHomeScreen.qml"

require_line() {
    local file="$1"
    local needle="$2"

    if ! grep -Fq "$needle" "$file"; then
        echo "Missing invariant in ${file#$repo_root/}: $needle" >&2
        exit 1
    fi
}

require_line "$constants" "readonly property real convergenceDockHeight: Kirigami.Units.gridUnit * 3"
require_line "$constants" "readonly property real convergenceDockRevealHeight: Kirigami.Units.gridUnit"

require_line "$taskpanel" "height: MobileShell.Constants.convergenceDockHeight"
require_line "$taskpanel" "LayerShell.Window.exclusionZone: MobileShell.Constants.convergenceDockHeight"

require_line "$folio_main" "height: MobileShell.Constants.convergenceDockHeight"
require_line "$folio_main" "readonly property real dockHeight: MobileShell.Constants.convergenceDockHeight"
require_line "$folio_main" "readonly property real revealStripHeight: MobileShell.Constants.convergenceDockRevealHeight"
require_line "$folio_home" "height: ShellSettings.Settings.convergenceModeEnabled ? MobileShell.Constants.convergenceDockHeight : Kirigami.Units.gridUnit * 6"

dock_offset_transforms="$(grep -F "transform: Translate { y: dockOverlay.dockOffset }" "$folio_main" | wc -l)"
if [[ "$dock_offset_transforms" -ne 1 ]]; then
    echo "Expected only dock contents to slide with dockOverlay.dockOffset; found $dock_offset_transforms transforms" >&2
    exit 1
fi
