// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

struct SDL_Gamepad;

class GamepadDevice : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

    Q_PROPERTY(int deviceId READ deviceId CONSTANT)
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QString type READ type CONSTANT)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryPercentChanged)
    Q_PROPERTY(bool hasRumble READ hasRumble CONSTANT)
    Q_PROPERTY(bool hasTriggerRumble READ hasTriggerRumble CONSTANT)
    Q_PROPERTY(bool hasLED READ hasLED CONSTANT)
    Q_PROPERTY(int touchpadCount READ touchpadCount CONSTANT)
    Q_PROPERTY(bool hasGyro READ hasGyro CONSTANT)
    Q_PROPERTY(bool hasAccelerometer READ hasAccelerometer CONSTANT)
    Q_PROPERTY(int playerIndex READ playerIndex WRITE setPlayerIndex NOTIFY playerIndexChanged)

public:
    explicit GamepadDevice(SDL_Gamepad *pad, int id, QObject *parent = nullptr);
    ~GamepadDevice() override;

    int deviceId() const;
    QString name() const;
    QString type() const;
    int batteryPercent() const;
    bool hasRumble() const;
    bool hasTriggerRumble() const;
    bool hasLED() const;
    int touchpadCount() const;
    bool hasGyro() const;
    bool hasAccelerometer() const;
    int playerIndex() const;
    void setPlayerIndex(int index);

    Q_INVOKABLE bool rumble(int lowIntensity, int highIntensity, int durationMs);
    Q_INVOKABLE bool rumbleTriggers(int leftIntensity, int rightIntensity, int durationMs);
    Q_INVOKABLE bool setLED(int r, int g, int b);
    Q_INVOKABLE QString buttonLabel(int button) const;

    SDL_Gamepad *sdlGamepad() const;
    void refreshBattery();

Q_SIGNALS:
    void batteryPercentChanged();
    void playerIndexChanged();

private:
    SDL_Gamepad *m_pad = nullptr;
    int m_id = 0;
    int m_batteryPercent = -1;
};
