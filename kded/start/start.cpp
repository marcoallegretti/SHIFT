// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: GPL-2.0-or-later

#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

#include <KConfigGroup>
#include <KIO/CommandLauncherJob>
#include <KNotificationJobUiDelegate>
#include <KPluginFactory>
#include <KSharedConfig>

#include "start.h"

namespace
{
bool isLegacyNextWallpaperPath(const QString &path)
{
    return path == QStringLiteral("Next") || path.startsWith(QStringLiteral("/usr/share/wallpapers/Next/"))
        || path.startsWith(QStringLiteral("file:///usr/share/wallpapers/Next/"));
}

QString shiftWallpaperPackageUrl()
{
    const QString metadataPath = QStandardPaths::locate(QStandardPaths::GenericDataLocation, QStringLiteral("wallpapers/SHIFT/metadata.json"));
    if (metadataPath.isEmpty()) {
        return QString();
    }

    QString packageUrl = QUrl::fromLocalFile(QFileInfo(metadataPath).absolutePath()).toString();
    if (!packageUrl.endsWith(QLatin1Char('/'))) {
        packageUrl += QLatin1Char('/');
    }
    return packageUrl;
}

void ensureLockscreenWallpaperDefaults()
{
    auto config = KSharedConfig::openConfig(QStringLiteral("kscreenlockerrc"));
    auto greeterGroup = config->group(QStringLiteral("Greeter"));

    const QString wallpaperPlugin = greeterGroup.readEntry(QStringLiteral("WallpaperPlugin"), QString());
    const QString wallpaperPath =
        greeterGroup.group(QStringLiteral("Wallpaper")).group(wallpaperPlugin).group(QStringLiteral("General")).readEntry(QStringLiteral("Image"), QString());

    const bool wallpaperUnset = wallpaperPlugin.isEmpty() || wallpaperPath.isEmpty();
    const bool wallpaperLegacyNext = wallpaperPlugin == QStringLiteral("org.kde.image") && isLegacyNextWallpaperPath(wallpaperPath);
    if (!wallpaperUnset && !wallpaperLegacyNext) {
        return;
    }

    const QString defaultWallpaperUrl = shiftWallpaperPackageUrl();
    if (defaultWallpaperUrl.isEmpty()) {
        qWarning() << "Could not locate SHIFT wallpaper package for lockscreen defaults";
        return;
    }

    greeterGroup.group(QStringLiteral("Wallpaper"))
        .group(QStringLiteral("org.kde.image"))
        .group(QStringLiteral("General"))
        .writeEntry(QStringLiteral("Image"), defaultWallpaperUrl, KConfigGroup::Notify);
    greeterGroup.writeEntry(QStringLiteral("WallpaperPlugin"), QStringLiteral("org.kde.image"), KConfigGroup::Notify);
    config->sync();
}
}

K_PLUGIN_FACTORY_WITH_JSON(StartFactory, "kded_plasma_mobile_start.json", registerPlugin<Start>();)

Start::Start(QObject *parent, const QList<QVariant> &)
    : KDEDModule{parent}
{
    ensureLockscreenWallpaperDefaults();

    auto *envmanagerJob = new KIO::CommandLauncherJob(QStringLiteral("plasma-mobile-envmanager --apply-settings"), {});
    envmanagerJob->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoErrorHandlingEnabled));
    envmanagerJob->setDesktopName(QStringLiteral("org.kde.plasma-mobile-envmanager"));
    envmanagerJob->start();

    auto *initialstartJob = new KIO::CommandLauncherJob(QStringLiteral("plasma-mobile-initial-start"), {});
    initialstartJob->setUiDelegate(new KNotificationJobUiDelegate(KJobUiDelegate::AutoErrorHandlingEnabled));
    initialstartJob->setDesktopName(QStringLiteral("org.kde.plasma-mobile-initial-start"));
    initialstartJob->start();
}

#include "start.moc"
