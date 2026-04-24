// SPDX-FileCopyrightText: 2026 Marco Allegretti
// SPDX-License-Identifier: EUPL-1.2

#include "gamelauncherprovider.h"

#include <KConfigGroup>
#include <KIO/ApplicationLauncherJob>
#include <KJob>
#include <KService>
#include <KSharedConfig>
#include <KShell>
#include <KSycoca>

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTextStream>

#include <memory>

static const QString s_recentGroup = QStringLiteral("GamingRecentlyPlayed");
static const QString s_waydroidGamingGroup = QStringLiteral("WaydroidGaming");
static const QString s_gameShellPackagesKey = QStringLiteral("gameShellPackages");

namespace
{
struct VdfNode {
    QHash<QString, QString> values;
    QHash<QString, std::shared_ptr<VdfNode>> children;
};

class VdfTokenizer
{
public:
    enum class TokenType {
        End,
        String,
        OpenBrace,
        CloseBrace,
        Invalid,
    };

    struct Token {
        TokenType type = TokenType::End;
        QString text;
    };

    explicit VdfTokenizer(QStringView input)
        : m_input(input)
    {
    }

    Token next()
    {
        skipWhitespaceAndComments();

        if (m_pos >= m_input.size()) {
            return {};
        }

        const QChar current = m_input.at(m_pos);
        if (current == QLatin1Char('{')) {
            ++m_pos;
            return {TokenType::OpenBrace, {}};
        }
        if (current == QLatin1Char('}')) {
            ++m_pos;
            return {TokenType::CloseBrace, {}};
        }
        if (current == QLatin1Char('"')) {
            bool terminated = false;
            const QString text = readQuotedString(&terminated);
            if (!terminated) {
                return {TokenType::Invalid, text};
            }
            return {TokenType::String, text};
        }

        return {TokenType::String, readBareString()};
    }

    int position() const
    {
        return m_pos;
    }

private:
    void skipWhitespaceAndComments()
    {
        while (m_pos < m_input.size()) {
            const QChar current = m_input.at(m_pos);
            if (current.isSpace()) {
                ++m_pos;
                continue;
            }
            if (current == QLatin1Char('/') && m_pos + 1 < m_input.size() && m_input.at(m_pos + 1) == QLatin1Char('/')) {
                m_pos += 2;
                while (m_pos < m_input.size() && m_input.at(m_pos) != QLatin1Char('\n')) {
                    ++m_pos;
                }
                continue;
            }
            break;
        }
    }

    QString readQuotedString(bool *terminated)
    {
        QString result;
        ++m_pos;

        if (terminated) {
            *terminated = false;
        }

        while (m_pos < m_input.size()) {
            const QChar current = m_input.at(m_pos++);
            if (current == QLatin1Char('"')) {
                if (terminated) {
                    *terminated = true;
                }
                return result;
            }
            if (current == QLatin1Char('\\') && m_pos < m_input.size()) {
                const QChar escaped = m_input.at(m_pos++);
                switch (escaped.unicode()) {
                case 'n':
                    result.append(QLatin1Char('\n'));
                    break;
                case 't':
                    result.append(QLatin1Char('\t'));
                    break;
                case 'r':
                    result.append(QLatin1Char('\r'));
                    break;
                case '\\':
                case '"':
                    result.append(escaped);
                    break;
                default:
                    result.append(escaped);
                    break;
                }
                continue;
            }
            result.append(current);
        }

        return result;
    }

    QString readBareString()
    {
        const int start = m_pos;
        while (m_pos < m_input.size()) {
            const QChar current = m_input.at(m_pos);
            if (current.isSpace() || current == QLatin1Char('{') || current == QLatin1Char('}') || current == QLatin1Char('"')) {
                break;
            }
            if (current == QLatin1Char('/') && m_pos + 1 < m_input.size() && m_input.at(m_pos + 1) == QLatin1Char('/')) {
                break;
            }
            ++m_pos;
        }
        return m_input.sliced(start, m_pos - start).toString();
    }

    QStringView m_input;
    int m_pos = 0;
};

bool parseVdf(const QString &input, VdfNode &root, QString *error)
{
    VdfTokenizer tokenizer(input);
    QList<VdfNode *> stack = {&root};

    while (true) {
        const auto key = tokenizer.next();
        if (key.type == VdfTokenizer::TokenType::End) {
            if (stack.size() != 1 && error) {
                *error = QStringLiteral("unexpected end of file");
            }
            return stack.size() == 1;
        }
        if (key.type == VdfTokenizer::TokenType::CloseBrace) {
            if (stack.size() == 1) {
                if (error) {
                    *error = QStringLiteral("unexpected closing brace at position %1").arg(tokenizer.position());
                }
                return false;
            }
            stack.removeLast();
            continue;
        }
        if (key.type != VdfTokenizer::TokenType::String || key.text.isEmpty()) {
            if (error) {
                *error = QStringLiteral("invalid key at position %1").arg(tokenizer.position());
            }
            return false;
        }

        const auto value = tokenizer.next();
        if (value.type == VdfTokenizer::TokenType::String) {
            stack.last()->values.insert(key.text, value.text);
            continue;
        }
        if (value.type == VdfTokenizer::TokenType::OpenBrace) {
            auto child = std::make_shared<VdfNode>();
            stack.last()->children.insert(key.text, child);
            stack.append(child.get());
            continue;
        }

        if (error) {
            *error = QStringLiteral("expected value for key '%1'").arg(key.text);
        }
        return false;
    }
}

QString waydroidPackageFromService(const KService::Ptr &service)
{
    static const QRegularExpression execPattern(QStringLiteral("^waydroid\\s+app\\s+launch\\s+([^\\s%]+)"));
    const QRegularExpressionMatch execMatch = execPattern.match(service->exec());
    if (execMatch.hasMatch()) {
        return execMatch.captured(1);
    }

    static const QRegularExpression storageIdPattern(QStringLiteral("^waydroid\\.(.+)\\.desktop$"));
    const QRegularExpressionMatch storageIdMatch = storageIdPattern.match(service->storageId());
    if (!storageIdMatch.hasMatch()) {
        return {};
    }

    return storageIdMatch.captured(1);
}

QStringList waydroidGameShellPackages(const KSharedConfigPtr &config)
{
    const KConfigGroup group(config, s_waydroidGamingGroup);
    return group.readEntry(s_gameShellPackagesKey, QStringList{});
}
} // namespace

GameLauncherProvider::GameLauncherProvider(QObject *parent)
    : QAbstractListModel(parent)
    , m_config(KSharedConfig::openConfig(QStringLiteral("plasmamobilerc")))
{
    connect(KSycoca::self(), &KSycoca::databaseChanged, this, &GameLauncherProvider::refresh);
    m_configWatcher = KConfigWatcher::create(m_config);
    connect(m_configWatcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == s_waydroidGamingGroup) {
            m_config->reparseConfiguration();
            refresh();
        }
    });
    m_pendingLaunchTimer.setInterval(15000);
    m_pendingLaunchTimer.setSingleShot(true);
    connect(&m_pendingLaunchTimer, &QTimer::timeout, this, &GameLauncherProvider::clearPendingLaunch);
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

bool GameLauncherProvider::launchPending() const
{
    return m_launchPending;
}

QString GameLauncherProvider::pendingLaunchName() const
{
    return m_pendingLaunchName;
}

QString GameLauncherProvider::lastLaunchError() const
{
    return m_lastLaunchError;
}

void GameLauncherProvider::refresh()
{
    m_loading = true;
    Q_EMIT loadingChanged();

    m_allGames.clear();

    loadDesktopGames();
    loadSteamGames();
    loadFlatpakGames();
    loadLutrisGames();
    loadHeroicGames();
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
    clearLastLaunchError();

    if (entry.source == QLatin1String("desktop") || entry.source == QLatin1String("waydroid")) {
        auto service = KService::serviceByStorageId(entry.storageId);
        if (!service) {
            markLaunchFailed(entry.name, QStringLiteral("Desktop entry is no longer available"));
            return;
        }

        auto *job = new KIO::ApplicationLauncherJob(service);
        connect(job, &KJob::result, this, [this, job, storageId = entry.storageId, name = entry.name]() {
            if (job->error() != 0) {
                markLaunchFailed(name, job->errorString());
                return;
            }
            markLaunchSucceeded(storageId, name);
        });
        job->start();
    } else if (entry.launchCommand.contains(QStringLiteral("://"))) {
        // Protocol handler (e.g. heroic://launch/...) — open via xdg-open
        if (!QProcess::startDetached(QStringLiteral("xdg-open"), {entry.launchCommand})) {
            markLaunchFailed(entry.name, QStringLiteral("Unable to start xdg-open"));
            return;
        }
        markLaunchSucceeded(entry.storageId, entry.name);
    } else {
        QStringList parts = KShell::splitArgs(entry.launchCommand);
        if (parts.isEmpty()) {
            markLaunchFailed(entry.name, QStringLiteral("Launch command is empty"));
            return;
        }

        QString program = parts.takeFirst();
        if (!QProcess::startDetached(program, parts)) {
            markLaunchFailed(entry.name, QStringLiteral("Unable to start %1").arg(program));
            return;
        }
        markLaunchSucceeded(entry.storageId, entry.name);
    }
}

void GameLauncherProvider::deduplicateGames()
{
    // Build a set of names from dedicated launcher entries (case-insensitive).
    // These have better artwork and metadata, so they win over plain .desktop entries.
    QSet<QString> launcherNames;
    for (const auto &g : std::as_const(m_allGames)) {
        if (g.source == QLatin1String("steam") || g.source == QLatin1String("lutris") || g.source == QLatin1String("heroic")) {
            launcherNames.insert(g.name.toLower());
        }
    }

    // Remove desktop entries whose name matches a launcher entry.
    m_allGames.erase(std::remove_if(m_allGames.begin(),
                                    m_allGames.end(),
                                    [&launcherNames](const GameEntry &g) {
                                        return g.source == QLatin1String("desktop") && launcherNames.contains(g.name.toLower());
                                    }),
                     m_allGames.end());
}

// --- XDG .desktop games ---

void GameLauncherProvider::loadDesktopGames()
{
    const QStringList allowedWaydroidPackages = waydroidGameShellPackages(m_config);
    const QSet<QString> enabledWaydroidPackages(allowedWaydroidPackages.cbegin(), allowedWaydroidPackages.cend());
    const auto services = KService::allServices();
    for (const auto &service : services) {
        if (service->noDisplay() || service->exec().isEmpty()) {
            continue;
        }
        const QStringList cats = service->categories();
        bool isGame = false;
        bool isWaydroidApp = false;
        for (const auto &cat : cats) {
            if (cat.compare(QLatin1String("Game"), Qt::CaseInsensitive) == 0) {
                isGame = true;
            } else if (cat.compare(QLatin1String("X-WayDroid-App"), Qt::CaseInsensitive) == 0) {
                isWaydroidApp = true;
            }
        }
        if (!isGame) {
            if (!isWaydroidApp) {
                continue;
            }

            const QString packageName = waydroidPackageFromService(service);
            if (packageName.isEmpty() || !enabledWaydroidPackages.contains(packageName)) {
                continue;
            }
        }

        GameEntry entry;
        entry.name = service->name();
        entry.icon = service->icon();
        entry.source = isWaydroidApp ? QStringLiteral("waydroid") : QStringLiteral("desktop");
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
        const QString content = QString::fromUtf8(vdf.readAll());
        VdfNode document;
        QString error;
        if (!parseVdf(content, document, &error)) {
            qWarning() << "GameLauncherProvider: cannot parse Steam libraryfolders" << vdfPath << error;
            continue;
        }

        const VdfNode *libraries = nullptr;
        if (document.children.contains(QStringLiteral("libraryfolders"))) {
            libraries = document.children.value(QStringLiteral("libraryfolders")).get();
        } else {
            libraries = &document;
        }

        for (auto it = libraries->children.cbegin(); it != libraries->children.cend(); ++it) {
            const QString path = it.value()->values.value(QStringLiteral("path"));
            if (!path.isEmpty()) {
                libraryPaths.append(path);
            }
        }
    }

    libraryPaths.removeDuplicates();

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
            VdfNode manifestData;
            QString error;
            if (!parseVdf(QString::fromUtf8(f.readAll()), manifestData, &error)) {
                qWarning() << "GameLauncherProvider: cannot parse Steam manifest" << manifest << error;
                continue;
            }

            const VdfNode *appState =
                manifestData.children.contains(QStringLiteral("AppState")) ? manifestData.children.value(QStringLiteral("AppState")).get() : &manifestData;

            const QString appName = appState->values.value(QStringLiteral("name"));
            const QString appId = appState->values.value(QStringLiteral("appid"));

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

// --- Lutris library (SQLite) ---

void GameLauncherProvider::loadLutrisGames()
{
    const QString dbPath = QDir::homePath() + QStringLiteral("/.local/share/lutris/pga.db");
    if (!QFile::exists(dbPath)) {
        return;
    }

    // Use a unique connection name to avoid conflicting with other code.
    // RAII guard ensures QSqlDatabase::removeDatabase runs on every exit path.
    const QString connName = QStringLiteral("lutris_games_%1").arg(reinterpret_cast<quintptr>(this));
    const auto dbCleanup = qScopeGuard([&connName]() {
        QSqlDatabase::removeDatabase(connName);
    });
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(dbPath);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));

        if (!db.open()) {
            qWarning() << "GameLauncherProvider: cannot open Lutris DB" << dbPath;
            return;
        }

        QSqlQuery query(db);
        query.prepare(QStringLiteral("SELECT name, slug, runner, coverart, id FROM games WHERE installed = 1"));

        if (!query.exec()) {
            qWarning() << "GameLauncherProvider: Lutris query failed";
            db.close();
            return;
        }

        const QString coverBase = QDir::homePath() + QStringLiteral("/.local/share/lutris/coverart/");

        while (query.next()) {
            GameEntry entry;
            entry.name = query.value(0).toString();
            const QString slug = query.value(1).toString();
            const QString runner = query.value(2).toString();
            const QString coverart = query.value(3).toString();
            const int gameId = query.value(4).toInt();

            entry.source = QStringLiteral("lutris");
            entry.storageId = QStringLiteral("lutris:%1").arg(slug);
            entry.icon = QStringLiteral("lutris");
            entry.launchCommand = QStringLiteral("lutris lutris:rungameid/%1").arg(gameId);
            entry.installed = true;

            // Cover art: Lutris stores covers in ~/.local/share/lutris/coverart/
            if (!coverart.isEmpty()) {
                entry.artwork = coverart;
            } else {
                const QString coverFile = coverBase + slug + QStringLiteral(".jpg");
                if (QFile::exists(coverFile)) {
                    entry.artwork = coverFile;
                }
            }

            m_allGames.append(entry);
        }

        db.close();
    }
    // dbCleanup guard handles QSqlDatabase::removeDatabase(connName)
}

// --- Heroic Games Launcher (JSON) ---

void GameLauncherProvider::loadHeroicGames()
{
    // Heroic stores library caches for different stores
    const QString heroicBase = QDir::homePath() + QStringLiteral("/.config/heroic");
    if (!QDir(heroicBase).exists()) {
        return;
    }

    // Check both GOG and Epic (Legendary) library caches
    const QStringList libFiles = {
        heroicBase + QStringLiteral("/store_cache/gog_library.json"),
        heroicBase + QStringLiteral("/store_cache/legendary_library.json"),
        heroicBase + QStringLiteral("/store_cache/nile_library.json"),
    };

    for (const auto &libPath : libFiles) {
        QFile libFile(libPath);
        if (!libFile.open(QIODevice::ReadOnly)) {
            continue;
        }

        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(libFile.readAll(), &err);
        if (err.error != QJsonParseError::NoError) {
            qWarning() << "GameLauncherProvider: JSON parse error in" << libPath << err.errorString();
            continue;
        }

        // Heroic library JSON: { "library": [ { "app_name": ..., "title": ..., ... } ] }
        // or it can be a plain array at the top level
        QJsonArray games;
        if (doc.isArray()) {
            games = doc.array();
        } else if (doc.isObject()) {
            games = doc.object().value(QStringLiteral("library")).toArray();
            if (games.isEmpty()) {
                games = doc.object().value(QStringLiteral("games")).toArray();
            }
        }

        const bool isGog = libPath.contains(QStringLiteral("gog"));
        const bool isNile = libPath.contains(QStringLiteral("nile"));

        for (const auto &val : games) {
            const QJsonObject obj = val.toObject();
            const QString appName = obj.value(QStringLiteral("app_name")).toString();
            const QString title = obj.value(QStringLiteral("title")).toString();

            if (title.isEmpty()) {
                continue;
            }

            // Check if installed
            const auto isInstalled = obj.value(QStringLiteral("is_installed"));
            if (isInstalled.isBool() && !isInstalled.toBool()) {
                continue;
            }

            GameEntry entry;
            entry.name = title;
            entry.source = QStringLiteral("heroic");
            entry.storageId = QStringLiteral("heroic:%1").arg(appName);
            entry.icon = QStringLiteral("heroic");
            entry.installed = true;

            // Launch via Heroic protocol handler
            if (isGog) {
                entry.launchCommand = QStringLiteral("heroic://launch/gog/%1").arg(appName);
            } else if (isNile) {
                entry.launchCommand = QStringLiteral("heroic://launch/nile/%1").arg(appName);
            } else {
                entry.launchCommand = QStringLiteral("heroic://launch/legendary/%1").arg(appName);
            }

            // Cover art: Heroic caches artwork
            const QString artPath = obj.value(QStringLiteral("art_cover")).toString();
            if (!artPath.isEmpty() && QFile::exists(artPath)) {
                entry.artwork = artPath;
            } else {
                // Try Heroic's thumbnail cache
                const QString thumbDir = heroicBase + QStringLiteral("/images/") + appName + QStringLiteral("/");
                const QDir thumbs(thumbDir);
                if (thumbs.exists()) {
                    const auto images = thumbs.entryList({QStringLiteral("*.jpg"), QStringLiteral("*.png"), QStringLiteral("*.webp")}, QDir::Files);
                    if (!images.isEmpty()) {
                        entry.artwork = thumbDir + images.first();
                    }
                }
            }

            m_allGames.append(entry);
        }
    }
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

bool GameLauncherProvider::overlayEnabled() const
{
    return m_overlayEnabled;
}

void GameLauncherProvider::setOverlayEnabled(bool enabled)
{
    if (m_overlayEnabled == enabled) {
        return;
    }
    m_overlayEnabled = enabled;
    Q_EMIT overlayEnabledChanged();

    // Set/unset MangoHud environment variables for child processes
    if (enabled) {
        qputenv("MANGOHUD", "1");
        qputenv("MANGOHUD_DLSYM", "1");
    } else {
        qunsetenv("MANGOHUD");
        qunsetenv("MANGOHUD_DLSYM");
    }
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

void GameLauncherProvider::clearPendingLaunch()
{
    if (!m_launchPending && m_pendingLaunchName.isEmpty()) {
        return;
    }

    m_pendingLaunchTimer.stop();
    m_launchPending = false;
    m_pendingLaunchName.clear();
    Q_EMIT launchPendingChanged();
}

void GameLauncherProvider::clearLastLaunchError()
{
    if (m_lastLaunchError.isEmpty()) {
        return;
    }

    m_lastLaunchError.clear();
    Q_EMIT lastLaunchErrorChanged();
}

int GameLauncherProvider::findEntryIndexByStorageId(const QString &storageId) const
{
    for (int index = 0; index < m_allGames.size(); ++index) {
        if (m_allGames.at(index).storageId == storageId) {
            return index;
        }
    }
    return -1;
}

void GameLauncherProvider::markLaunchSucceeded(const QString &storageId, const QString &name)
{
    const int entryIndex = findEntryIndexByStorageId(storageId);
    if (entryIndex >= 0) {
        auto &entry = m_allGames[entryIndex];
        const auto now = QDateTime::currentDateTime();
        saveRecentTimestamp(entry.storageId, now);
        entry.lastPlayed = now;
    }

    setPendingLaunch(name);
    Q_EMIT gameLaunched(name);
}

void GameLauncherProvider::markLaunchFailed(const QString &name, const QString &error)
{
    clearPendingLaunch();

    const QString message = error.isEmpty() ? tr("Unable to launch %1").arg(name) : tr("Unable to launch %1: %2").arg(name, error);

    if (m_lastLaunchError != message) {
        m_lastLaunchError = message;
        Q_EMIT lastLaunchErrorChanged();
    }

    Q_EMIT gameLaunchFailed(name, message);
}

void GameLauncherProvider::setPendingLaunch(const QString &name)
{
    const bool changed = !m_launchPending || m_pendingLaunchName != name;
    m_launchPending = true;
    m_pendingLaunchName = name;
    m_pendingLaunchTimer.start();

    if (changed) {
        Q_EMIT launchPendingChanged();
    }
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
