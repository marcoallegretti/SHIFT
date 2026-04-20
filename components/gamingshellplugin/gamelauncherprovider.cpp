// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamelauncherprovider.h"

#include <KConfigGroup>
#include <KService>
#include <KSharedConfig>
#include <KShell>
#include <KSycoca>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>

static const QString s_recentGroup = QStringLiteral("GamingRecentlyPlayed");

GameLauncherProvider::GameLauncherProvider(QObject *parent)
    : QAbstractListModel(parent)
    , m_config(KSharedConfig::openConfig(QStringLiteral("plasmamobilerc")))
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

    m_allGames.clear();

    loadDesktopGames();
    loadSteamGames();
    loadFlatpakGames();
    loadRecentTimestamps();

    // Deduplicate: when the same game appears from multiple sources,
    // prefer Steam (has artwork + Proton handling) over desktop.
    deduplicateGames();

    // Sort alphabetically, case-insensitive
    std::sort(m_allGames.begin(), m_allGames.end(), [](const GameEntry &a, const GameEntry &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    applyFilter();

    m_loading = false;
    Q_EMIT loadingChanged();
}

void GameLauncherProvider::launch(int index)
{
    if (index < 0 || index >= m_games.size()) {
        return;
    }
    // Find the matching entry in m_allGames so the timestamp update persists
    const QString &sid = m_games.at(index).storageId;
    for (auto &entry : m_allGames) {
        if (entry.storageId == sid) {
            launchEntry(entry);
            return;
        }
    }
}

void GameLauncherProvider::launchByStorageId(const QString &storageId)
{
    for (auto &entry : m_allGames) {
        if (entry.storageId == storageId) {
            launchEntry(entry);
            return;
        }
    }
}

void GameLauncherProvider::launchEntry(GameEntry &entry)
{
    if (entry.source == QLatin1String("desktop")) {
        auto service = KService::serviceByStorageId(entry.storageId);
        if (service) {
            QStringList args = KShell::splitArgs(service->exec());
            if (!args.isEmpty()) {
                QString program = args.takeFirst();
                QProcess::startDetached(program, args);
            }
        }
    } else {
        QStringList parts = entry.launchCommand.split(QLatin1Char(' '));
        if (!parts.isEmpty()) {
            QString program = parts.takeFirst();
            QProcess::startDetached(program, parts);
        }
    }

    Q_EMIT gameLaunched(entry.name);
    const auto now = QDateTime::currentDateTime();
    saveRecentTimestamp(entry.storageId, now);
    entry.lastPlayed = now;
}

void GameLauncherProvider::deduplicateGames()
{
    // Build a set of names from Steam entries (case-insensitive).
    QSet<QString> steamNames;
    for (const auto &g : std::as_const(m_allGames)) {
        if (g.source == QLatin1String("steam")) {
            steamNames.insert(g.name.toLower());
        }
    }

    // Remove desktop entries whose name matches a Steam entry.
    m_allGames.erase(std::remove_if(m_allGames.begin(),
                                    m_allGames.end(),
                                    [&steamNames](const GameEntry &g) {
                                        return g.source == QLatin1String("desktop") && steamNames.contains(g.name.toLower());
                                    }),
                     m_allGames.end());
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
        m_allGames.append(entry);
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

            m_allGames.append(entry);
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

QString GameLauncherProvider::filterString() const
{
    return m_filterString;
}

void GameLauncherProvider::setFilterString(const QString &filter)
{
    if (m_filterString == filter) {
        return;
    }
    m_filterString = filter;
    Q_EMIT filterStringChanged();
    applyFilter();
}

QString GameLauncherProvider::sourceFilter() const
{
    return m_sourceFilter;
}

void GameLauncherProvider::setSourceFilter(const QString &source)
{
    if (m_sourceFilter == source) {
        return;
    }
    m_sourceFilter = source;
    Q_EMIT sourceFilterChanged();
    applyFilter();
}

void GameLauncherProvider::applyFilter()
{
    beginResetModel();
    m_games.clear();

    for (const auto &g : std::as_const(m_allGames)) {
        if (!m_sourceFilter.isEmpty() && g.source != m_sourceFilter) {
            continue;
        }
        if (!m_filterString.isEmpty() && !g.name.contains(m_filterString, Qt::CaseInsensitive)) {
            continue;
        }
        m_games.append(g);
    }

    endResetModel();
    Q_EMIT countChanged();
}

void GameLauncherProvider::loadRecentTimestamps()
{
    const KConfigGroup group(m_config, s_recentGroup);
    for (auto &entry : m_allGames) {
        const QString key = entry.storageId;
        if (group.hasKey(key)) {
            entry.lastPlayed = group.readEntry(key, QDateTime());
        }
    }
}

void GameLauncherProvider::saveRecentTimestamp(const QString &storageId, const QDateTime &when)
{
    KConfigGroup group(m_config, s_recentGroup);
    group.writeEntry(storageId, when);
    group.sync();
}

QVariantList GameLauncherProvider::recentGames(int limit) const
{
    // Gather entries that have been launched at least once
    QList<const GameEntry *> recent;
    for (const auto &g : m_allGames) {
        if (g.lastPlayed.isValid()) {
            recent.append(&g);
        }
    }

    // Most recent first
    std::sort(recent.begin(), recent.end(), [](const GameEntry *a, const GameEntry *b) {
        return a->lastPlayed > b->lastPlayed;
    });

    if (recent.size() > limit) {
        recent.resize(limit);
    }

    QVariantList result;
    result.reserve(recent.size());
    for (const auto *g : recent) {
        QVariantMap map;
        map[QStringLiteral("name")] = g->name;
        map[QStringLiteral("icon")] = g->icon;
        map[QStringLiteral("source")] = g->source;
        map[QStringLiteral("storageId")] = g->storageId;
        map[QStringLiteral("artwork")] = g->artwork;
        result.append(map);
    }
    return result;
}
