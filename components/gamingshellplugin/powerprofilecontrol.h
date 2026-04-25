// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QDBusInterface>
#include <QObject>
#include <QStringList>
#include <qqmlregistration.h>

class PowerProfileControl : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString activeProfile READ activeProfile WRITE setActiveProfile NOTIFY activeProfileChanged)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY profilesChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit PowerProfileControl(QObject *parent = nullptr);

    QString activeProfile() const;
    void setActiveProfile(const QString &profile);
    QStringList profiles() const;
    bool available() const;

Q_SIGNALS:
    void activeProfileChanged();
    void profilesChanged();
    void availableChanged();

private Q_SLOTS:
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void fetchState();

    QDBusInterface *m_iface = nullptr;
    QString m_activeProfile;
    QStringList m_profiles;
    bool m_available = false;
};
