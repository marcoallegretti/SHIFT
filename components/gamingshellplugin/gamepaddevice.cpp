// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamepaddevice.h"

#include <SDL3/SDL_gamepad.h>
#include <SDL3/SDL_power.h>
#include <SDL3/SDL_properties.h>

GamepadDevice::GamepadDevice(SDL_Gamepad *pad, int id, QObject *parent)
    : QObject(parent)
    , m_pad(pad)
    , m_id(id)
{
    refreshBattery();
}

GamepadDevice::~GamepadDevice()
{
    if (m_pad) {
        SDL_CloseGamepad(m_pad);
        m_pad = nullptr;
    }
}

int GamepadDevice::deviceId() const
{
    return m_id;
}

QString GamepadDevice::name() const
{
    if (!m_pad) {
        return {};
    }
    const char *n = SDL_GetGamepadName(m_pad);
    return n ? QString::fromUtf8(n) : QString();
}

QString GamepadDevice::type() const
{
    if (!m_pad) {
        return QStringLiteral("unknown");
    }
    switch (SDL_GetGamepadType(m_pad)) {
    case SDL_GAMEPAD_TYPE_XBOX360:
    case SDL_GAMEPAD_TYPE_XBOXONE:
        return QStringLiteral("xbox");
    case SDL_GAMEPAD_TYPE_PS3:
    case SDL_GAMEPAD_TYPE_PS4:
    case SDL_GAMEPAD_TYPE_PS5:
        return QStringLiteral("playstation");
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:
    case SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
        return QStringLiteral("nintendo");
    default:
        return QStringLiteral("generic");
    }
}

int GamepadDevice::batteryPercent() const
{
    return m_batteryPercent;
}

bool GamepadDevice::hasRumble() const
{
    if (!m_pad) {
        return false;
    }
    SDL_PropertiesID props = SDL_GetGamepadProperties(m_pad);
    return SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false);
}

bool GamepadDevice::hasLED() const
{
    if (!m_pad) {
        return false;
    }
    SDL_PropertiesID props = SDL_GetGamepadProperties(m_pad);
    return SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN, false);
}

int GamepadDevice::playerIndex() const
{
    if (!m_pad) {
        return -1;
    }
    return SDL_GetGamepadPlayerIndex(m_pad);
}

void GamepadDevice::setPlayerIndex(int index)
{
    if (!m_pad) {
        return;
    }
    SDL_SetGamepadPlayerIndex(m_pad, index);
    Q_EMIT playerIndexChanged();
}

bool GamepadDevice::rumble(int lowFreqMs, int highFreqMs, int durationMs)
{
    if (!m_pad) {
        return false;
    }
    return SDL_RumbleGamepad(m_pad, static_cast<uint16_t>(lowFreqMs), static_cast<uint16_t>(highFreqMs), static_cast<uint32_t>(durationMs));
}

bool GamepadDevice::setLED(int r, int g, int b)
{
    if (!m_pad) {
        return false;
    }
    return SDL_SetGamepadLED(m_pad, static_cast<uint8_t>(r), static_cast<uint8_t>(g), static_cast<uint8_t>(b));
}

SDL_Gamepad *GamepadDevice::sdlGamepad() const
{
    return m_pad;
}

void GamepadDevice::refreshBattery()
{
    if (!m_pad) {
        return;
    }
    int pct = -1;
    SDL_GetGamepadPowerInfo(m_pad, &pct);
    if (pct != m_batteryPercent) {
        m_batteryPercent = pct;
        Q_EMIT batteryPercentChanged();
    }
}
