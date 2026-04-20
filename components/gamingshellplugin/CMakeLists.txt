# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: EUPL-1.2

find_package(SDL3 REQUIRED)

ecm_add_qml_module(gamingshellplugin URI org.kde.plasma.private.mobileshell.gamingshellplugin GENERATE_PLUGIN_SOURCE)

target_sources(gamingshellplugin PRIVATE
    gamepadmanager.cpp
    gamepaddevice.cpp
    gamelauncherprovider.cpp
)

target_link_libraries(gamingshellplugin PRIVATE
    Qt::Core
    Qt::Qml
    Qt::Quick
    KF6::I18n
    KF6::Service
    KF6::CoreAddons
    SDL3::SDL3
)

ecm_finalize_qml_module(gamingshellplugin)
