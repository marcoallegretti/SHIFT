// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#pragma once

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QQuickItem>

namespace Plasma
{
class Applet;
class Containment;
class Corona;
}

namespace PlasmaQuick
{
class AppletQuickItem;
}

class AppletHost : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit AppletHost(QObject *parent = nullptr);
    ~AppletHost() override;

    static QObject *create(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
    {
        return new AppletHost();
    }

    Q_INVOKABLE QQuickItem *fullRepresentationFor(const QString &pluginId);

Q_SIGNALS:
    void appletReady(const QString &pluginId);

private:
    void ensureCorona();

    class HostCorona;
    HostCorona *m_corona = nullptr;
    Plasma::Containment *m_containment = nullptr;
    QHash<QString, PlasmaQuick::AppletQuickItem *> m_items;
};
