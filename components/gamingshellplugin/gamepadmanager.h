// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QAbstractListModel>
#include <QTimer>
#include <qqmlregistration.h>

class QQmlEngine;
class QJSEngine;
class GamepadDevice;

class GamepadManager : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(GamepadDevice *primaryGamepad READ primaryGamepad NOTIFY primaryGamepadChanged)
    Q_PROPERTY(bool hasGamepad READ hasGamepad NOTIFY countChanged)

public:
    explicit GamepadManager(QObject *parent = nullptr);
    ~GamepadManager() override;

    static GamepadManager *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    enum Roles {
        DeviceRole = Qt::UserRole + 1,
        NameRole,
        TypeRole,
        BatteryRole,
    };
    Q_ENUM(Roles)

    // Buttons matching SDL_GamepadButton, re-exported for QML
    enum Button {
        ButtonA,
        ButtonB,
        ButtonX,
        ButtonY,
        ButtonBack,
        ButtonGuide,
        ButtonStart,
        ButtonLeftStick,
        ButtonRightStick,
        ButtonLeftShoulder,
        ButtonRightShoulder,
        ButtonDPadUp,
        ButtonDPadDown,
        ButtonDPadLeft,
        ButtonDPadRight,
        ButtonMisc1,
    };
    Q_ENUM(Button)

    // Axes matching SDL_GamepadAxis
    enum Axis {
        AxisLeftX,
        AxisLeftY,
        AxisRightX,
        AxisRightY,
        AxisLeftTrigger,
        AxisRightTrigger,
    };
    Q_ENUM(Axis)

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool active() const;
    void setActive(bool active);
    int count() const;
    bool hasGamepad() const;
    GamepadDevice *primaryGamepad() const;

    Q_INVOKABLE GamepadDevice *gamepadAt(int index) const;
    Q_INVOKABLE QString buttonLabel(int button, int gamepadIndex = -1) const;

Q_SIGNALS:
    void activeChanged();
    void countChanged();
    void primaryGamepadChanged();

    void buttonPressed(int button, int gamepadIndex);
    void buttonReleased(int button, int gamepadIndex);
    void axisChanged(int axis, float value, int gamepadIndex);

private:
    void start();
    void stop();
    void poll();
    void addGamepad(int instanceId);
    void removeGamepad(int instanceId);
    int indexForInstanceId(int instanceId) const;

    bool m_active = false;
    bool m_sdlInitialized = false;
    int m_batteryCounter = 0;
    QTimer m_pollTimer;
    QList<GamepadDevice *> m_gamepads;
};
