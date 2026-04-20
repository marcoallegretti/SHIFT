// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamepadmanager.h"
#include "gamepaddevice.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_gamepad.h>

#include <QDebug>

GamepadManager::GamepadManager(QObject *parent)
    : QAbstractListModel(parent)
{
    m_pollTimer.setInterval(16); // ~60 Hz
    connect(&m_pollTimer, &QTimer::timeout, this, &GamepadManager::poll);
}

GamepadManager::~GamepadManager()
{
    stop();
}

// --- QAbstractListModel ---

int GamepadManager::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_gamepads.size();
}

QVariant GamepadManager::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_gamepads.size()) {
        return {};
    }
    auto *dev = m_gamepads.at(index.row());
    switch (role) {
    case DeviceRole:
        return QVariant::fromValue(dev);
    case NameRole:
        return dev->name();
    case TypeRole:
        return dev->type();
    case BatteryRole:
        return dev->batteryPercent();
    }
    return {};
}

QHash<int, QByteArray> GamepadManager::roleNames() const
{
    return {
        {DeviceRole, "device"},
        {NameRole, "name"},
        {TypeRole, "type"},
        {BatteryRole, "battery"},
    };
}

// --- Properties ---

bool GamepadManager::active() const
{
    return m_active;
}

void GamepadManager::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    if (active) {
        start();
    } else {
        stop();
    }
    Q_EMIT activeChanged();
}

int GamepadManager::count() const
{
    return m_gamepads.size();
}

bool GamepadManager::hasGamepad() const
{
    return !m_gamepads.isEmpty();
}

GamepadDevice *GamepadManager::primaryGamepad() const
{
    return m_gamepads.isEmpty() ? nullptr : m_gamepads.first();
}

GamepadDevice *GamepadManager::gamepadAt(int index) const
{
    if (index < 0 || index >= m_gamepads.size()) {
        return nullptr;
    }
    return m_gamepads.at(index);
}

// --- Lifecycle ---

void GamepadManager::start()
{
    if (m_sdlInitialized) {
        return;
    }
    if (!SDL_Init(SDL_INIT_GAMEPAD)) {
        qWarning() << "GamepadManager: SDL_Init failed:" << SDL_GetError();
        return;
    }
    m_sdlInitialized = true;

    // Enumerate already-connected gamepads
    int count = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&count);
    if (ids) {
        for (int i = 0; i < count; ++i) {
            addGamepad(ids[i]);
        }
        SDL_free(ids);
    }

    m_pollTimer.start();
}

void GamepadManager::stop()
{
    m_pollTimer.stop();

    if (!m_gamepads.isEmpty()) {
        beginResetModel();
        qDeleteAll(m_gamepads);
        m_gamepads.clear();
        endResetModel();
        Q_EMIT countChanged();
        Q_EMIT primaryGamepadChanged();
    }

    if (m_sdlInitialized) {
        SDL_QuitSubSystem(SDL_INIT_GAMEPAD);
        m_sdlInitialized = false;
    }
}

// --- Event polling ---

void GamepadManager::poll()
{
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
        case SDL_EVENT_GAMEPAD_ADDED:
            addGamepad(event.gdevice.which);
            break;

        case SDL_EVENT_GAMEPAD_REMOVED:
            removeGamepad(event.gdevice.which);
            break;

        case SDL_EVENT_GAMEPAD_BUTTON_DOWN: {
            int idx = indexForInstanceId(event.gbutton.which);
            if (idx >= 0) {
                Q_EMIT buttonPressed(event.gbutton.button, idx);
            }
            break;
        }

        case SDL_EVENT_GAMEPAD_BUTTON_UP: {
            int idx = indexForInstanceId(event.gbutton.which);
            if (idx >= 0) {
                Q_EMIT buttonReleased(event.gbutton.button, idx);
            }
            break;
        }

        case SDL_EVENT_GAMEPAD_AXIS_MOTION: {
            int idx = indexForInstanceId(event.gaxis.which);
            if (idx >= 0) {
                float normalized = static_cast<float>(event.gaxis.value) / 32767.0f;
                Q_EMIT axisChanged(event.gaxis.axis, normalized, idx);
            }
            break;
        }

        default:
            break;
        }
    }

    // Refresh battery state periodically (every ~5 seconds = 300 frames)
    static int batteryCounter = 0;
    if (++batteryCounter >= 300) {
        batteryCounter = 0;
        for (auto *dev : std::as_const(m_gamepads)) {
            dev->refreshBattery();
        }
    }
}

// --- Hotplug ---

void GamepadManager::addGamepad(int instanceId)
{
    // Already tracked?
    if (indexForInstanceId(instanceId) >= 0) {
        return;
    }

    SDL_Gamepad *pad = SDL_OpenGamepad(instanceId);
    if (!pad) {
        qWarning() << "GamepadManager: failed to open gamepad" << instanceId << SDL_GetError();
        return;
    }

    auto *device = new GamepadDevice(pad, instanceId, this);
    int row = m_gamepads.size();
    beginInsertRows(QModelIndex(), row, row);
    m_gamepads.append(device);
    endInsertRows();

    Q_EMIT countChanged();
    if (m_gamepads.size() == 1) {
        Q_EMIT primaryGamepadChanged();
    }

    qDebug() << "GamepadManager: connected" << device->name() << "(" << device->type() << ")";
}

void GamepadManager::removeGamepad(int instanceId)
{
    int idx = indexForInstanceId(instanceId);
    if (idx < 0) {
        return;
    }

    beginRemoveRows(QModelIndex(), idx, idx);
    auto *dev = m_gamepads.takeAt(idx);
    endRemoveRows();

    qDebug() << "GamepadManager: disconnected" << dev->name();
    dev->deleteLater();

    Q_EMIT countChanged();
    if (idx == 0) {
        Q_EMIT primaryGamepadChanged();
    }
}

int GamepadManager::indexForInstanceId(int instanceId) const
{
    for (int i = 0; i < m_gamepads.size(); ++i) {
        if (m_gamepads.at(i)->deviceId() == instanceId) {
            return i;
        }
    }
    return -1;
}
