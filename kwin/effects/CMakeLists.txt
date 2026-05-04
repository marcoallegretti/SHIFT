# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: EUPL-1.2

function(add_kwin_effect name source)
    kpackage_install_package(${source} ${name} effects kwin)

    file(COPY ${source}/contents ${source}/metadata.json DESTINATION ${CMAKE_BINARY_DIR}/bin/kwin/effects/${name})
endfunction()

add_kwin_effect(shift-snap-assist shift-snap-assist)
