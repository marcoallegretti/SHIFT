/*
 *   SPDX-FileCopyrightText: 2025 Florian RICHER <florian.richer@protonmail.com>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "flashlighthelper_debug.h"

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QLoggingCategory>
#include <QObject>

#include <libudev.h>

using namespace Qt::StringLiterals;

class Flashlighthelper : public QObject
{
    Q_OBJECT
public Q_SLOTS:
    KAuth::ActionReply setbrightness(const QVariantMap &args);
};

KAuth::ActionReply Flashlighthelper::setbrightness(const QVariantMap &args)
{
    // Store as named QByteArrays so constData() pointers remain valid for the
    // duration of the function. The originals were temporaries that were
    // destroyed at the end of each declaration statement.
    // (need to double-check this, but seems likely to be the cause of the random failures
    // we were seeing in testing)
    const QByteArray sysPathBytes = args.value("sysPath"_L1).toString().toUtf8();
    const QByteArray brightnessBytes = args.value("brightness"_L1).toString().toUtf8();

    if (sysPathBytes.isEmpty()) {
        qCWarning(FLASHLIGHTHELPER) << "sysPath argument is missing or empty";
        return KAuth::ActionReply::HelperErrorReply();
    }

    struct udev *udev = udev_new();
    if (!udev) {
        qCWarning(FLASHLIGHTHELPER) << "Failed to create udev context";
        return KAuth::ActionReply::HelperErrorReply();
    }

    struct udev_device *device = udev_device_new_from_syspath(udev, sysPathBytes.constData());
    if (!device) {
        qCWarning(FLASHLIGHTHELPER) << "Failed to find udev device for syspath:" << sysPathBytes;
        udev_unref(udev);
        return KAuth::ActionReply::HelperErrorReply();
    }

    // The libudev header declares value as const char*, so no cast needed.
    int ret = udev_device_set_sysattr_value(device, "brightness", brightnessBytes.constData());

    udev_device_unref(device);
    udev_unref(udev);

    if (ret >= 0) {
        return KAuth::ActionReply::SuccessReply();
    } else {
        qCWarning(FLASHLIGHTHELPER) << "Failed to set udev system attribute, errno:" << -ret;
        return KAuth::ActionReply::HelperErrorReply();
    }
}

KAUTH_HELPER_MAIN("org.kde.plasma.mobileshell.flashlighthelper", Flashlighthelper)

#include "flashlighthelper.moc"