// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamelauncherprovider.h"

#include <KService>
#include <KShell>
#include <KSycoca>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

GameLauncherProvider::GameLauncherProvider(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &GameLauncherProvider::refresh);
    refresh();
}

int GameLauncherProvider::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_games.size();
}

QVariant GameLauncherProvider::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_games.size()) {
        return {};
    }
    const auto &g = m_games.at(index.row());
    switch (role) {
    case NameRole:
        return g.name;
    case IconRole:
        return g.icon;
    case SourceRole:
        return g.source;
    case StorageIdRole:
        return g.storageId;
    case LaunchCommandRole:
        return g.launchCommand;
    case ArtworkRole:
        return g.artwork;
    case InstalledRole:
        return g.installed;
    }
    return {};
}

QHash<int, QByteArray> GameLauncherProvider::roleNames() const
{
    return {
        {NameRole, "name"},
        {IconRole, "icon"},
        {SourceRole, "source"},
        {StorageIdRole, "storageId"},
        {LaunchCommandRole, "launchCommand"},
        {ArtworkRole, "artwork"},
        {InstalledRole, "installed"},
    };
}

int GameLauncherProvider::count() const
{
    return m_games.size();
}

bool GameLauncherProvider::loading() const
{
    return m_loading;
}

void GameLauncherProvider::refresh()
{
    m_loading = true;
    Q_EMIT loadingChanged();

    beginResetModel();
    m_games.clear();

    loadDesktopGames();
    loadSteamGames();
    loadFlatpakGames();

    // Sort alphabetically, case-insensitive
    std::sort(m_games.begin(), m_games.end(), [](const GameEntry &a, const GameEntry &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    endResetModel();

    m_loading = false;
    Q_EMIT loadingChanged();
    Q_EMIT countChanged();
}

void GameLauncherProvider::launch(int index)
{
    if (index < 0 || index >= m_games.size()) {
        return;
    }
    const auto &g = m_games.at(index);

    if (g.source == QLatin1String("desktop")) {
        // Launch via KService for proper activation tracking
        auto service = KService::serviceByStorageId(g.storageId);
        if (service) {
            // Use QProcess to launch the exec line — KIO::ApplicationLauncherJob
            // would be better but requires KIOWidgets which is heavy for a plugin.
            QStringList args = KShell::splitArgs(service->exec());
            if (!args.isEmpty()) {
                QString program = args.takeFirst();
                QProcess::startDetached(program, args);
            }
        }
    } else {
        // Steam, Flatpak, etc. — run the launch command directly
        QStringList parts = g.launchCommand.split(QLatin1Char(' '));
        if (!parts.isEmpty()) {
            QString program = parts.takeFirst();
            QProcess::startDetached(program, parts);
        }
    }

    Q_EMIT gameLaunched(g.name);
}

// --- XDG .desktop games ---

void GameLauncherProvider::loadDesktopGames()
{
    const auto services = KService::allServices();
    for (const auto &service : services) {
        if (service->noDisplay() || service->exec().isEmpty()) {
            continue;
        }
        const QStringList cats = service->categories();
        bool isGame = false;
        for (const auto &cat : cats) {
            if (cat.compare(QLatin1String("Game"), Qt::CaseInsensitive) == 0) {
                isGame = true;
                break;
            }
        }
        if (!isGame) {
            continue;
        }

        GameEntry entry;
        entry.name = service->name();
        entry.icon = service->icon();
        entry.source = QStringLiteral("desktop");
        entry.storageId = service->storageId();
        entry.launchCommand = service->exec();
        entry.installed = true;
        m_games.append(entry);
    }
}

// --- Steam library ---

void GameLauncherProvider::loadSteamGames()
{
    // Look for Steam library folders
    const QStringList steamRoots = {
        QDir::homePath() + QStringLiteral("/.steam/steam"),
        QDir::homePath() + QStringLiteral("/.local/share/Steam"),
        // Flatpak Steam
        QDir::homePath() + QStringLiteral("/.var/app/com.valvesoftware.Steam/.steam/steam"),
        QDir::homePath() + QStringLiteral("/.var/app/com.valvesoftware.Steam/.local/share/Steam"),
    };

    QStringList libraryPaths;
    for (const auto &root : steamRoots) {
        const QString vdfPath = root + QStringLiteral("/steamapps/libraryfolders.vdf");
        QFile vdf(vdfPath);
        if (!vdf.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        // Simple parse: look for "path" lines
        static const QRegularExpression pathRe(QStringLiteral("\"path\"\\s+\"([^\"]+)\""));
        QTextStream stream(&vdf);
        while (!stream.atEnd()) {
            const QString line = stream.readLine();
            auto match = pathRe.match(line);
            if (match.hasMatch()) {
                libraryPaths.append(match.captured(1));
            }
        }
    }

    // Scan each library path for appmanifest_*.acf
    static const QRegularExpression nameRe(QStringLiteral("\"name\"\\s+\"([^\"]+)\""));
    static const QRegularExpression appidRe(QStringLiteral("\"appid\"\\s+\"(\\d+)\""));

    for (const auto &libPath : std::as_const(libraryPaths)) {
        QDir steamapps(libPath + QStringLiteral("/steamapps"));
        if (!steamapps.exists()) {
            continue;
        }
        const auto manifests = steamapps.entryList({QStringLiteral("appmanifest_*.acf")}, QDir::Files);
        for (const auto &manifest : manifests) {
            QFile f(steamapps.filePath(manifest));
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                continue;
            }
            QString appName;
            QString appId;
            QTextStream ts(&f);
            while (!ts.atEnd()) {
                const QString line = ts.readLine();
                if (appName.isEmpty()) {
                    auto m = nameRe.match(line);
                    if (m.hasMatch()) {
                        appName = m.captured(1);
                    }
                }
                if (appId.isEmpty()) {
                    auto m = appidRe.match(line);
                    if (m.hasMatch()) {
                        appId = m.captured(1);
                    }
                }
                if (!appName.isEmpty() && !appId.isEmpty()) {
                    break;
                }
            }

            if (appName.isEmpty() || appId.isEmpty()) {
                continue;
            }

            // Skip Steamworks Common Redistributables and Proton/tools
            if (appId == QLatin1String("228980")) {
                continue;
            }

            GameEntry entry;
            entry.name = appName;
            entry.icon = QStringLiteral("steam");
            entry.source = QStringLiteral("steam");
            entry.storageId = QStringLiteral("steam://rungameid/") + appId;
            entry.launchCommand = QStringLiteral("steam steam://rungameid/") + appId;
            entry.installed = true;

            // Check for grid artwork
            for (const auto &root : steamRoots) {
                const QString gridDir = root + QStringLiteral("/appcache/librarycache/") + appId;
                const QStringList artSuffixes = {
                    QStringLiteral("_library_600x900.jpg"),
                    QStringLiteral("_header.jpg"),
                };
                for (const auto &suffix : artSuffixes) {
                    const QString artPath = gridDir + suffix;
                    if (QFile::exists(artPath)) {
                        entry.artwork = artPath;
                        break;
                    }
                }
                if (!entry.artwork.isEmpty()) {
                    break;
                }
            }

            m_games.append(entry);
        }
    }
}

// --- Flatpak games (non-Steam) ---

void GameLauncherProvider::loadFlatpakGames()
{
    // Flatpak games that export .desktop files with Game category
    // are already picked up by loadDesktopGames() via KService.
    // This method is a hook for future Flatpak-specific enrichment
    // (e.g. querying flatpak metadata for games that don't set
    // the Game category properly).
}
