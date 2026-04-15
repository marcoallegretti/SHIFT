// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "applethost.h"

#include <Plasma/Containment>
#include <Plasma/Corona>
#include <Plasma/PluginLoader>
#include <PlasmaQuick/AppletQuickItem>

#include <KPackage/Package>
#include <KPackage/PackageLoader>

#include <QDebug>

using namespace Qt::StringLiterals;

// Minimal Corona to host applets outside the shell's own containment tree.
class AppletHost::HostCorona : public Plasma::Corona
{
    Q_OBJECT
public:
    explicit HostCorona(QObject *parent = nullptr)
        : Plasma::Corona(parent)
    {
        KPackage::Package pkg = KPackage::PackageLoader::self()->loadPackage(u"Plasma/Shell"_s);
        pkg.setPath(u"org.kde.plasma.mobile"_s);
        setKPackage(pkg);
    }

    QRect screenGeometry(int id) const override
    {
        Q_UNUSED(id);
        return {0, 0, 400, 600};
    }

    void loadDefaultLayout() override
    {
    }
};

AppletHost::AppletHost(QObject *parent)
    : QObject(parent)
{
}

AppletHost::~AppletHost() = default;

void AppletHost::ensureCorona()
{
    if (m_corona)
        return;

    m_corona = new HostCorona(this);

    m_containment = m_corona->createContainment(u"null"_s);
    if (m_containment) {
        m_containment->setFormFactor(Plasma::Types::Application);
    }
}

QQuickItem *AppletHost::fullRepresentationFor(const QString &pluginId)
{
    auto it = m_items.constFind(pluginId);
    if (it != m_items.constEnd()) {
        auto *item = *it;
        return item ? item->fullRepresentationItem() : nullptr;
    }

    ensureCorona();
    if (!m_containment) {
        qWarning() << "AppletHost: failed to create containment";
        return nullptr;
    }

    auto *applet = Plasma::PluginLoader::self()->loadApplet(pluginId, 0);
    if (!applet) {
        qWarning() << "AppletHost: failed to load applet" << pluginId;
        m_items.insert(pluginId, nullptr);
        return nullptr;
    }

    m_containment->addApplet(applet);
    auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
    m_items.insert(pluginId, item);

    if (!item) {
        qWarning() << "AppletHost: no AppletQuickItem for" << pluginId;
        return nullptr;
    }

    item->setPreloadFullRepresentation(true);

    return item->fullRepresentationItem();
}

#include "applethost.moc"
