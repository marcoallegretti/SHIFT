# SPDX-FileCopyrightText: 2024 Devin Lin <devin@kde.org>
# SPDX-License-Identifier: GPL-2.0-or-later

add_subdirectory(notificationtest)

find_program(BASH_EXECUTABLE bash)
if(BASH_EXECUTABLE)
    add_test(
        NAME convergence-dock-invariant
        COMMAND ${BASH_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/check-convergence-dock-invariant.sh
    )
endif()
