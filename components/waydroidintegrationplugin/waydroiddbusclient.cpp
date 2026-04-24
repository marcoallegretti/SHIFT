/*
 *   SPDX-FileCopyrightText: 2025 Florian RICHER <florian.richer@protonmail.com>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "waydroiddbusclient.h"

#include <KConfigGroup>

#include <QClipboard>
#include <QCoroDBusPendingReply>
#include <QDBusMessage>
#include <QGuiApplication>
#include <QTimer>

using namespace Qt::StringLiterals;

static const QString s_waydroidGamingGroup = QStringLiteral("WaydroidGaming");
static const QString s_gameShellPackagesKey = QStringLiteral("gameShellPackages");

WaydroidDBusClient::WaydroidDBusClient(QObject *parent)
    : QObject{parent}
    , m_interface{new OrgKdePlasmashellWaydroidInterface{u"org.kde.plasmashell"_s, u"/Waydroid"_s, QDBusConnection::sessionBus(), this}}
    , m_watcher{new QDBusServiceWatcher{u"org.kde.plasmashell"_s, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange, this}}
    , m_applicationListModel{new WaydroidApplicationListModel{this}}
    , m_config{KSharedConfig::openConfig(QStringLiteral("plasmamobilerc"))}
{
    m_configWatcher = KConfigWatcher::create(m_config);
    connect(m_configWatcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == s_waydroidGamingGroup) {
            m_config->reparseConfiguration();
            reloadGameShellPackages();
        }
    });
    reloadGameShellPackages();

    // Check if the service is already running
    if (QDBusConnection::sessionBus().interface()->isServiceRegistered(u"org.kde.plasmashell"_s)) {
        checkWaydroidObject();
    }

    connect(m_watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString &service, const QString &oldOwner, const QString &newOwner) {
        if (service == u"org.kde.plasmashell"_s) {
            if (newOwner.isEmpty()) {
                // Service stopped
                m_connected = false;
                m_connectionCheckPending = false;
                resetState();
            } else if (oldOwner.isEmpty()) {
                // Service started
                checkWaydroidObject();
            }
        }
    });
}

void WaydroidDBusClient::connectSignals()
{
    if (!m_signalsConnected) {
        m_signalsConnected = true;

        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::statusChanged, this, &WaydroidDBusClient::updateStatus);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::downloadStatusChanged, this, [this](double downloaded, double total, double speed) {
            Q_EMIT downloadStatusChanged(downloaded, total, speed);
        });
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::sessionStatusChanged, this, &WaydroidDBusClient::updateSessionStatus);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::systemTypeChanged, this, &WaydroidDBusClient::updateSystemType);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::ipAddressChanged, this, &WaydroidDBusClient::updateIpAddress);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::androidIdChanged, this, &WaydroidDBusClient::updateAndroidId);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::multiWindowsChanged, this, &WaydroidDBusClient::updateMultiWindows);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::suspendChanged, this, &WaydroidDBusClient::updateSuspend);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::ueventChanged, this, &WaydroidDBusClient::updateUevent);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::fakeTouchChanged, this, &WaydroidDBusClient::updateFakeTouch);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::fakeWifiChanged, this, &WaydroidDBusClient::updateFakeWifi);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::actionFinished, this, [this](const QString message) {
            Q_EMIT actionFinished(message);
        });
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::actionFailed, this, [this](const QString message) {
            Q_EMIT actionFailed(message);
        });
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::errorOccurred, this, [this](const QString title, const QString message) {
            Q_EMIT errorOccurred(title, message);
        });
    }

    initializeApplicationListModel();
    updateStatus();
    updateSessionStatus();
    updateSystemType();
    updateIpAddress();
    updateAndroidId();
    updateMultiWindows();
    updateSuspend();
    updateUevent();
    updateFakeTouch();
    updateFakeWifi();
}

void WaydroidDBusClient::checkWaydroidObject()
{
    if (m_connectionCheckPending) {
        return;
    }

    m_connectionCheckPending = true;

    const QDBusMessage message =
        QDBusMessage::createMethodCall(u"org.kde.plasmashell"_s, u"/Waydroid"_s, u"org.freedesktop.DBus.Introspectable"_s, u"Introspect"_s);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, &WaydroidDBusClient::onWaydroidObjectCheckFinished);
}

void WaydroidDBusClient::onWaydroidObjectCheckFinished(QDBusPendingCallWatcher *watcher)
{
    m_connectionCheckPending = false;

    QDBusPendingReply<QString> reply = *watcher;
    if (!reply.isValid()) {
        m_connected = false;
        watcher->deleteLater();
        resetState();
        scheduleWaydroidObjectCheck();
        return;
    }

    m_connected = true;
    watcher->deleteLater();

    if (m_interface->isValid()) {
        connectSignals();
    }
}

void WaydroidDBusClient::handleUnavailableReply()
{
    if (!m_connected) {
        return;
    }

    m_connected = false;
    resetState();
    scheduleWaydroidObjectCheck();
}

void WaydroidDBusClient::resetState()
{
    if (m_status != NotSupported) {
        m_status = NotSupported;
        Q_EMIT statusChanged();
    }

    if (m_sessionStatus != SessionStopped) {
        m_sessionStatus = SessionStopped;
        Q_EMIT sessionStatusChanged();
    }

    if (m_systemType != UnknownSystemType) {
        m_systemType = UnknownSystemType;
        Q_EMIT systemTypeChanged();
    }

    if (!m_ipAddress.isEmpty()) {
        m_ipAddress.clear();
        Q_EMIT ipAddressChanged();
    }

    if (!m_androidId.isEmpty()) {
        m_androidId.clear();
        Q_EMIT androidIdChanged();
    }

    if (m_multiWindows) {
        m_multiWindows = false;
        Q_EMIT multiWindowsChanged();
    }

    if (m_suspend) {
        m_suspend = false;
        Q_EMIT suspendChanged();
    }

    if (m_uevent) {
        m_uevent = false;
        Q_EMIT ueventChanged();
    }

    if (!m_fakeTouch.isEmpty()) {
        m_fakeTouch.clear();
        Q_EMIT fakeTouchChanged();
    }

    if (!m_fakeWifi.isEmpty()) {
        m_fakeWifi.clear();
        Q_EMIT fakeWifiChanged();
    }

    m_applicationListModel->clearApplications();
}

void WaydroidDBusClient::scheduleWaydroidObjectCheck()
{
    if (!QDBusConnection::sessionBus().interface()->isServiceRegistered(u"org.kde.plasmashell"_s)) {
        return;
    }

    QTimer::singleShot(1000, this, &WaydroidDBusClient::checkWaydroidObject);
}

void WaydroidDBusClient::initializeApplicationListModel()
{
    auto reply = m_interface->applications();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<QList<QDBusObjectPath>> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch applications:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto applications = reply.argumentAt<0>();

        m_applicationListModel->initializeApplications(applications);

        // Connect applicationListModel signals only when applications is synced
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::applicationAdded, m_applicationListModel, &WaydroidApplicationListModel::addApplication);
        connect(m_interface, &OrgKdePlasmashellWaydroidInterface::applicationRemoved, m_applicationListModel, &WaydroidApplicationListModel::removeApplication);

        watcher->deleteLater();
    });
}

WaydroidDBusClient::Status WaydroidDBusClient::status() const
{
    return m_status;
}

WaydroidDBusClient::SessionStatus WaydroidDBusClient::sessionStatus() const
{
    return m_sessionStatus;
}

WaydroidDBusClient::SystemType WaydroidDBusClient::systemType() const
{
    return m_systemType;
}

QString WaydroidDBusClient::ipAddress() const
{
    return m_ipAddress;
}

QString WaydroidDBusClient::androidId() const
{
    return m_androidId;
}

WaydroidApplicationListModel *WaydroidDBusClient::applicationListModel() const
{
    return m_applicationListModel;
}

QCoro::Task<void> WaydroidDBusClient::setMultiWindowsTask(const bool multiWindows)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->setMultiWindows(multiWindows);
}

QCoro::QmlTask WaydroidDBusClient::setMultiWindows(const bool multiWindows)
{
    return setMultiWindowsTask(multiWindows);
}

bool WaydroidDBusClient::multiWindows() const
{
    return m_multiWindows;
}

QCoro::Task<void> WaydroidDBusClient::setSuspendTask(const bool suspend)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->setSuspend(suspend);
}

QCoro::QmlTask WaydroidDBusClient::setSuspend(const bool suspend)
{
    return setSuspendTask(suspend);
}

bool WaydroidDBusClient::suspend() const
{
    return m_suspend;
}

QCoro::Task<void> WaydroidDBusClient::setUeventTask(const bool uevent)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->setUevent(uevent);
}

QCoro::QmlTask WaydroidDBusClient::setUevent(const bool uevent)
{
    return setUeventTask(uevent);
}

QCoro::Task<void> WaydroidDBusClient::refreshSessionInfoTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->refreshSessionInfo();
}

QCoro::QmlTask WaydroidDBusClient::refreshSessionInfo()
{
    return refreshSessionInfoTask();
}

QCoro::Task<void> WaydroidDBusClient::refreshAndroidIdTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->refreshAndroidId();
}

QCoro::QmlTask WaydroidDBusClient::refreshAndroidId()
{
    return refreshAndroidIdTask();
}

QCoro::Task<void> WaydroidDBusClient::refreshApplicationsTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->refreshApplications();
}

QCoro::QmlTask WaydroidDBusClient::refreshApplications()
{
    return refreshApplicationsTask();
}

bool WaydroidDBusClient::gameShellEnabledForPackage(const QString &packageName) const
{
    return m_gameShellPackages.contains(packageName);
}

void WaydroidDBusClient::setGameShellEnabledForPackage(const QString &packageName, bool enabled)
{
    QStringList packages = m_gameShellPackages;
    packages.removeAll(packageName);
    if (enabled) {
        packages.append(packageName);
    }
    packages.removeDuplicates();
    packages.sort();

    if (packages == m_gameShellPackages) {
        return;
    }

    KConfigGroup group(m_config, s_waydroidGamingGroup);
    group.writeEntry(s_gameShellPackagesKey, packages, KConfigGroup::Notify);
    m_config->sync();

    m_gameShellPackages = packages;
    Q_EMIT gameShellPackagesChanged();
}

bool WaydroidDBusClient::uevent() const
{
    return m_uevent;
}

QCoro::Task<void> WaydroidDBusClient::setFakeTouchTask(const QString &fakeTouch)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->setFakeTouch(fakeTouch);
}

QCoro::QmlTask WaydroidDBusClient::setFakeTouch(const QString &fakeTouch)
{
    return setFakeTouchTask(fakeTouch);
}

QString WaydroidDBusClient::fakeTouch() const
{
    return m_fakeTouch;
}

QCoro::Task<void> WaydroidDBusClient::setFakeWifiTask(const QString &fakeWifi)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->setFakeWifi(fakeWifi);
}

QCoro::QmlTask WaydroidDBusClient::setFakeWifi(const QString &fakeWifi)
{
    return setFakeWifiTask(fakeWifi);
}

QString WaydroidDBusClient::fakeWifi() const
{
    return m_fakeWifi;
}

QStringList WaydroidDBusClient::gameShellPackages() const
{
    return m_gameShellPackages;
}

QCoro::Task<void> WaydroidDBusClient::initializeTask(const SystemType systemType, const RomType romType, const bool forced)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->initialize(systemType, romType, forced);
}

QCoro::QmlTask WaydroidDBusClient::initialize(const SystemType systemType, const RomType romType, const bool forced)
{
    return initializeTask(systemType, romType, forced);
}

QCoro::Task<void> WaydroidDBusClient::startSessionTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->startSession();
}

QCoro::QmlTask WaydroidDBusClient::startSession()
{
    return startSessionTask();
}

QCoro::Task<void> WaydroidDBusClient::stopSessionTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->stopSession();
}

QCoro::QmlTask WaydroidDBusClient::stopSession()
{
    return stopSessionTask();
}

QCoro::Task<void> WaydroidDBusClient::resetWaydroidTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->resetWaydroid();
}

QCoro::QmlTask WaydroidDBusClient::resetWaydroid()
{
    return resetWaydroidTask();
}

QCoro::Task<void> WaydroidDBusClient::installApkTask(const QString apkFile)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->installApk(apkFile);
}

QCoro::QmlTask WaydroidDBusClient::installApk(const QString apkFile)
{
    return installApkTask(apkFile);
}

QCoro::Task<void> WaydroidDBusClient::launchApplicationTask(const QString appId)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->launchApplication(appId);
}

QCoro::QmlTask WaydroidDBusClient::launchApplication(const QString appId)
{
    return launchApplicationTask(appId);
}

QCoro::Task<void> WaydroidDBusClient::deleteApplicationTask(const QString appId)
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->deleteApplication(appId);
}

QCoro::QmlTask WaydroidDBusClient::deleteApplication(const QString appId)
{
    return deleteApplicationTask(appId);
}

QCoro::Task<void> WaydroidDBusClient::refreshSupportsInfoTask()
{
    if (!m_connected) {
        co_return;
    }

    co_await m_interface->refreshSupportsInfo();
}

QCoro::QmlTask WaydroidDBusClient::refreshSupportsInfo()
{
    return refreshSupportsInfoTask();
}

void WaydroidDBusClient::updateStatus()
{
    auto reply = m_interface->status();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<int> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch status:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto status = static_cast<Status>(reply.argumentAt<0>());

        if (m_status != status) {
            m_status = status;
            Q_EMIT statusChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateSessionStatus()
{
    auto reply = m_interface->sessionStatus();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<int> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch sessionStatus:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto sessionStatus = static_cast<SessionStatus>(reply.argumentAt<0>());

        if (m_sessionStatus != sessionStatus) {
            m_sessionStatus = sessionStatus;
            Q_EMIT sessionStatusChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateSystemType()
{
    auto reply = m_interface->systemType();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<int> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch systemType:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto systemType = static_cast<SystemType>(reply.argumentAt<0>());

        if (m_systemType != systemType) {
            m_systemType = systemType;
            Q_EMIT systemTypeChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateIpAddress()
{
    auto reply = m_interface->ipAddress();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<QString> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch ipAddress:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto ipAddress = reply.argumentAt<0>();

        if (m_ipAddress != ipAddress) {
            m_ipAddress = ipAddress;
            Q_EMIT ipAddressChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateAndroidId()
{
    auto reply = m_interface->androidId();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<QString> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch androidId:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto androidId = reply.argumentAt<0>();

        if (m_androidId != androidId) {
            m_androidId = androidId;
            Q_EMIT androidIdChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateMultiWindows()
{
    auto reply = m_interface->multiWindows();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<bool> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch multiWindows:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto multiWindows = reply.argumentAt<0>();

        if (m_multiWindows != multiWindows) {
            m_multiWindows = multiWindows;
            Q_EMIT multiWindowsChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateSuspend()
{
    auto reply = m_interface->suspend();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<bool> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch suspend:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto suspend = reply.argumentAt<0>();

        if (m_suspend != suspend) {
            m_suspend = suspend;
            Q_EMIT suspendChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateUevent()
{
    auto reply = m_interface->uevent();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<bool> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch uevent:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const auto uevent = reply.argumentAt<0>();

        if (m_uevent != uevent) {
            m_uevent = uevent;
            Q_EMIT ueventChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateFakeTouch()
{
    auto reply = m_interface->fakeTouch();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<QString> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch fakeTouch:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const QString fakeTouch = reply.argumentAt<0>();

        if (m_fakeTouch != fakeTouch) {
            m_fakeTouch = fakeTouch;
            Q_EMIT fakeTouchChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::updateFakeWifi()
{
    auto reply = m_interface->fakeWifi();
    auto watcher = new QDBusPendingCallWatcher(reply, this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](auto watcher) {
        QDBusPendingReply<QString> reply = *watcher;
        if (!reply.isValid()) {
            qDebug() << "WaydroidDBusClient: Failed to fetch fakeWifi:" << reply.error().message();
            handleUnavailableReply();
            watcher->deleteLater();
            return;
        }

        const QString fakeWifi = reply.argumentAt<0>();

        if (m_fakeWifi != fakeWifi) {
            m_fakeWifi = fakeWifi;
            Q_EMIT fakeWifiChanged();
        }

        watcher->deleteLater();
    });
}

void WaydroidDBusClient::copyToClipboard(const QString text)
{
    qGuiApp->clipboard()->setText(text);
}

void WaydroidDBusClient::reloadGameShellPackages()
{
    const KConfigGroup group(m_config, s_waydroidGamingGroup);
    QStringList packages = group.readEntry(s_gameShellPackagesKey, QStringList{});
    packages.removeDuplicates();
    packages.sort();

    if (m_gameShellPackages == packages) {
        return;
    }

    m_gameShellPackages = packages;
    Q_EMIT gameShellPackagesChanged();
}
