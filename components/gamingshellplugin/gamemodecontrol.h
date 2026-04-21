// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QDBusInterface>
#include <QObject>
#include <qqmlregistration.h>

/**
 * D-Bus client for Feral GameMode (com.feralinteractive.GameMode).
 *
 * Calling requestStart() tells the daemon to apply performance
 * optimizations (CPU governor, I/O priority, GPU perf mode, etc.)
 * for the calling process. requestEnd() reverses them.
 *
 * GameMode is optional — if the daemon is not installed the calls
 * are silently ignored.
 */
class GameModeControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit GameModeControl(QObject *parent = nullptr);

    bool available() const;
    bool active() const;

    Q_INVOKABLE void requestStart();
    Q_INVOKABLE void requestEnd();

Q_SIGNALS:
    void availableChanged();
    void activeChanged();

private:
    QDBusInterface *m_iface = nullptr;
    bool m_available = false;
    bool m_active = false;
};
