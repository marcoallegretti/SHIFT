// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamepaddevice.h"

#include <SDL3/SDL_gamepad.h>
#include <SDL3/SDL_power.h>
#include <SDL3/SDL_properties.h>
#include <SDL3/SDL_sensor.h>

#include <algorithm>

static QString gamepadButtonLabelToString(SDL_GamepadButtonLabel label)
{
    switch (label) {
    case SDL_GAMEPAD_BUTTON_LABEL_A:
        return QStringLiteral("A");
    case SDL_GAMEPAD_BUTTON_LABEL_B:
        return QStringLiteral("B");
    case SDL_GAMEPAD_BUTTON_LABEL_X:
        return QStringLiteral("X");
    case SDL_GAMEPAD_BUTTON_LABEL_Y:
        return QStringLiteral("Y");
    case SDL_GAMEPAD_BUTTON_LABEL_CROSS:
        return QStringLiteral("Cross");
    case SDL_GAMEPAD_BUTTON_LABEL_CIRCLE:
        return QStringLiteral("Circle");
    case SDL_GAMEPAD_BUTTON_LABEL_SQUARE:
        return QStringLiteral("Square");
    case SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE:
        return QStringLiteral("Triangle");
    default:
        return QStringLiteral("?");
    }
}

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

bool GamepadDevice::hasTriggerRumble() const
{
    if (!m_pad) {
        return false;
    }
    SDL_PropertiesID props = SDL_GetGamepadProperties(m_pad);
    return SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_TRIGGER_RUMBLE_BOOLEAN, false);
}

bool GamepadDevice::hasLED() const
{
    if (!m_pad) {
        return false;
    }
    SDL_PropertiesID props = SDL_GetGamepadProperties(m_pad);
    return SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RGB_LED_BOOLEAN, false);
}

int GamepadDevice::touchpadCount() const
{
    if (!m_pad) {
        return 0;
    }
    return SDL_GetNumGamepadTouchpads(m_pad);
}

bool GamepadDevice::hasGyro() const
{
    return m_pad && SDL_GamepadHasSensor(m_pad, SDL_SENSOR_GYRO);
}

bool GamepadDevice::hasAccelerometer() const
{
    return m_pad && SDL_GamepadHasSensor(m_pad, SDL_SENSOR_ACCEL);
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
    if (SDL_SetGamepadPlayerIndex(m_pad, index)) {
        Q_EMIT playerIndexChanged();
    }
}

bool GamepadDevice::rumble(int lowIntensity, int highIntensity, int durationMs)
{
    if (!m_pad) {
        return false;
    }
    auto lo = static_cast<uint16_t>(std::clamp(lowIntensity, 0, 65535));
    auto hi = static_cast<uint16_t>(std::clamp(highIntensity, 0, 65535));
    auto dur = static_cast<uint32_t>(std::clamp(durationMs, 0, durationMs));
    return SDL_RumbleGamepad(m_pad, lo, hi, dur);
}

bool GamepadDevice::rumbleTriggers(int leftIntensity, int rightIntensity, int durationMs)
{
    if (!m_pad) {
        return false;
    }
    auto left = static_cast<uint16_t>(std::clamp(leftIntensity, 0, 65535));
    auto right = static_cast<uint16_t>(std::clamp(rightIntensity, 0, 65535));
    auto dur = static_cast<uint32_t>(std::clamp(durationMs, 0, durationMs));
    return SDL_RumbleGamepadTriggers(m_pad, left, right, dur);
}

bool GamepadDevice::setLED(int r, int g, int b)
{
    if (!m_pad) {
        return false;
    }
    auto cr = static_cast<uint8_t>(std::clamp(r, 0, 255));
    auto cg = static_cast<uint8_t>(std::clamp(g, 0, 255));
    auto cb = static_cast<uint8_t>(std::clamp(b, 0, 255));
    return SDL_SetGamepadLED(m_pad, cr, cg, cb);
}

QString GamepadDevice::buttonLabel(int button) const
{
    if (!m_pad) {
        return QStringLiteral("?");
    }

    switch (button) {
    case SDL_GAMEPAD_BUTTON_SOUTH:
    case SDL_GAMEPAD_BUTTON_EAST:
    case SDL_GAMEPAD_BUTTON_WEST:
    case SDL_GAMEPAD_BUTTON_NORTH:
        return gamepadButtonLabelToString(SDL_GetGamepadButtonLabel(m_pad, static_cast<SDL_GamepadButton>(button)));
    case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:
        return type() == QLatin1String("playstation") ? QStringLiteral("L1") : type() == QLatin1String("nintendo") ? QStringLiteral("L") : QStringLiteral("LB");
    case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER:
        return type() == QLatin1String("playstation") ? QStringLiteral("R1") : type() == QLatin1String("nintendo") ? QStringLiteral("R") : QStringLiteral("RB");
    case SDL_GAMEPAD_BUTTON_BACK:
        return type() == QLatin1String("playstation") ? QStringLiteral("Create")
            : type() == QLatin1String("nintendo")     ? QStringLiteral("-")
                                                      : QStringLiteral("View");
    case SDL_GAMEPAD_BUTTON_START:
        return type() == QLatin1String("playstation") ? QStringLiteral("Options")
            : type() == QLatin1String("nintendo")     ? QStringLiteral("+")
                                                      : QStringLiteral("Menu");
    case SDL_GAMEPAD_BUTTON_GUIDE:
        return type() == QLatin1String("playstation") ? QStringLiteral("PS")
            : type() == QLatin1String("nintendo")     ? QStringLiteral("Home")
                                                      : QStringLiteral("Guide");
    default:
        return QStringLiteral("?");
    }
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
