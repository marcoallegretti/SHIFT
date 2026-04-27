# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: GPL-2.0-or-later

include(ECMInstallIcons)

ecm_install_icons(
    ICONS sc-places-start-here-shift.svg
    DESTINATION ${KDE_INSTALL_ICONDIR}
    THEME hicolor
)
