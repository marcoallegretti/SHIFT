// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "powerprofilecontrol.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusReply>
#include <QDBusVariant>
#include <QDebug>

static const QString s_service = QStringLiteral("net.hadess.PowerProfiles");
static const QString s_path = QStringLiteral("/net/hadess/PowerProfiles");
static const QString s_iface = QStringLiteral("net.hadess.PowerProfiles");
static const QString s_propIface = QStringLiteral("org.freedesktop.DBus.Properties");

PowerProfileControl::PowerProfileControl(QObject *parent)
    : QObject(parent)
    , m_iface(new QDBusInterface(s_service, s_path, s_iface, QDBusConnection::systemBus(), this))
{
    if (m_iface->isValid()) {
        m_available = true;
        fetchState();

        // Subscribe to property changes
        QDBusConnection::systemBus()
            .connect(s_service, s_path, s_propIface, QStringLiteral("PropertiesChanged"), this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    } else {
        qDebug() << "PowerProfileControl: power-profiles-daemon not available";
    }
}

QString PowerProfileControl::activeProfile() const
{
    return m_activeProfile;
}

void PowerProfileControl::setActiveProfile(const QString &profile)
{
    if (!m_available || profile == m_activeProfile) {
        return;
    }
    if (!m_profiles.contains(profile)) {
        return;
    }

    // Write via org.freedesktop.DBus.Properties.Set
    QDBusInterface propIface(s_service, s_path, s_propIface, QDBusConnection::systemBus());
    propIface.call(QStringLiteral("Set"), s_iface, QStringLiteral("ActiveProfile"), QVariant::fromValue(QDBusVariant(profile)));
}

QStringList PowerProfileControl::profiles() const
{
    return m_profiles;
}

bool PowerProfileControl::available() const
{
    return m_available;
}

void PowerProfileControl::fetchState()
{
    // Read ActiveProfile
    QDBusInterface propIface(s_service, s_path, s_propIface, QDBusConnection::systemBus());

    QDBusReply<QDBusVariant> profileReply = propIface.call(QStringLiteral("Get"), s_iface, QStringLiteral("ActiveProfile"));
    if (profileReply.isValid()) {
        const QString profile = profileReply.value().variant().toString();
        if (profile != m_activeProfile) {
            m_activeProfile = profile;
            Q_EMIT activeProfileChanged();
        }
    }

    // Read Profiles — array of dicts, each with a "Profile" key
    QDBusReply<QDBusVariant> profilesReply = propIface.call(QStringLiteral("Get"), s_iface, QStringLiteral("Profiles"));
    if (profilesReply.isValid()) {
        QStringList profiles;
        const QVariant profilesVariant = profilesReply.value().variant();
        if (profilesVariant.canConvert<QVariantList>()) {
            const QVariantList list = profilesVariant.toList();
            for (const QVariant &item : list) {
                const QVariantMap map = item.toMap();
                QString profileName;
                if (map.contains(QStringLiteral("Profile"))) {
                    QVariant value = map.value(QStringLiteral("Profile"));
                    if (value.canConvert<QDBusVariant>()) {
                        value = value.value<QDBusVariant>().variant();
                    }
                    profileName = value.toString();
                }
                if (!profileName.isEmpty()) {
                    profiles.append(profileName);
                }
            }
        }
        if (profiles != m_profiles) {
            m_profiles = profiles;
            Q_EMIT profilesChanged();
        }
    }
}

void PowerProfileControl::onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated)
{
    Q_UNUSED(invalidated)
    if (interface != s_iface) {
        return;
    }

    if (changed.contains(QStringLiteral("ActiveProfile"))) {
        QVariant value = changed.value(QStringLiteral("ActiveProfile"));
        if (value.canConvert<QDBusVariant>()) {
            value = value.value<QDBusVariant>().variant();
        }
        const QString profile = value.toString();
        if (profile != m_activeProfile) {
            m_activeProfile = profile;
            Q_EMIT activeProfileChanged();
        }
    }

    if (changed.contains(QStringLiteral("Profiles"))) {
        fetchState();
    }
}
