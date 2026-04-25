// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamemodecontrol.h"

#include <QDBusConnection>
#include <QDBusReply>
#include <QDebug>

#include <unistd.h> // getpid()

static const QString s_service = QStringLiteral("com.feralinteractive.GameMode");
static const QString s_path = QStringLiteral("/com/feralinteractive/GameMode");
static const QString s_iface = QStringLiteral("com.feralinteractive.GameMode");

GameModeControl::GameModeControl(QObject *parent)
    : QObject(parent)
    , m_iface(new QDBusInterface(s_service, s_path, s_iface, QDBusConnection::sessionBus(), this))
{
    m_available = m_iface->isValid();
    if (!m_available) {
        qDebug() << "GameModeControl: Feral GameMode not available";
    }
}

bool GameModeControl::available() const
{
    return m_available;
}

bool GameModeControl::active() const
{
    return m_active;
}

void GameModeControl::requestStart()
{
    if (!m_available || m_active) {
        return;
    }

    QDBusReply<int> reply = m_iface->call(QStringLiteral("RegisterGame"), static_cast<int>(getpid()));
    if (reply.isValid() && reply.value() == 0) {
        m_active = true;
        Q_EMIT activeChanged();
    } else {
        qWarning() << "GameModeControl: RegisterGame failed:" << reply.error().message();
    }
}

void GameModeControl::requestEnd()
{
    if (!m_available || !m_active) {
        return;
    }

    QDBusReply<int> reply = m_iface->call(QStringLiteral("UnregisterGame"), static_cast<int>(getpid()));
    if (reply.isValid() && reply.value() == 0) {
        m_active = false;
        Q_EMIT activeChanged();
    } else {
        qWarning() << "GameModeControl: UnregisterGame failed:" << reply.error().message();
    }
}
