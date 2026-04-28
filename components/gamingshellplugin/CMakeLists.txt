# SPDX-FileCopyrightText: 2026 Marco Allegretti
# SPDX-License-Identifier: EUPL-1.2

find_package(Qt6 REQUIRED COMPONENTS Sql DBus)

ecm_add_qml_module(gamingshellplugin URI org.kde.plasma.private.mobileshell.gamingshellplugin GENERATE_PLUGIN_SOURCE)

target_sources(gamingshellplugin PRIVATE
    gamepadmanager.cpp
    gamepaddevice.cpp
    gamelauncherprovider.cpp
    powerprofilecontrol.cpp
    gamemodecontrol.cpp
)

target_link_libraries(gamingshellplugin PRIVATE
    Qt::Core
    Qt::DBus
    Qt::Qml
    Qt::Quick
    Qt::Sql
    KF6::I18n
    KF6::KIOGui
    KF6::Service
    KF6::CoreAddons
    KF6::ConfigCore
    SDL3::SDL3
)

ecm_finalize_qml_module(gamingshellplugin)
